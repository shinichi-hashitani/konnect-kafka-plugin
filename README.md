# KafkaとKonnect - プロトコル変換とKSQLによるデータ集計

Kafkaは高速かつ大量のイベントを安定的に処理できるデータプラットフォームです。本サンプルでは、Kongに対するREST APIのリクエストをKafkaプロトコルフォーマットに変換する処理を順を追って説明します。

環境としてはKongの管理にKong Konnect、Kafka及びKSQL (ストリーム処理) にConfluent Platformを利用します。

- Konnect: SaaSでありバージョンは単一
- Kong Gateway: 3.14
- Confluent Platform: 8.2
- Docker: 29.4
- Docker Compose: 2.32
- Insomnia 12.5

Kafka側の作業は原則Confluent Control Centerを利用します。1部機能においてControl Centerでは処理できないものもありますが、全体像を把握いただく上では問題ありません。

## 環境設定

###Confluent Platformの起動
このリポジトリをclone後、取得されたkonnect-kafka-pluginフォルダに移動の上、Docker Composeを起動

```bash
docker compose up -d

docker ps
CONTAINER ID   IMAGE                                                      COMMAND                   CREATED          STATUS          PORTS                                                                                                                                   NAMES
fca4501e5eb4   confluentinc/cp-enterprise-control-center-next-gen:2.5.0   "/etc/confluent/dock…"   13 seconds ago   Up 12 seconds   0.0.0.0:9021->9021/tcp, [::]:9021->9021/tcp                                                                                             control-center
fb8023502451   confluentinc/cp-ksqldb-server:8.2.0                        "/etc/confluent/dock…"   13 seconds ago   Up 12 seconds   0.0.0.0:8088->8088/tcp, [::]:8088->8088/tcp                                                                                             ksqldb-server
05d96f99c8ac   cnfldemos/cp-server-connect-datagen:0.6.4-7.6.0            "/etc/confluent/dock…"   13 seconds ago   Up 12 seconds   0.0.0.0:8083->8083/tcp, [::]:8083->8083/tcp                                                                                             connect
da4dce7c1978   confluentinc/cp-schema-registry:8.2.0                      "/etc/confluent/dock…"   13 seconds ago   Up 12 seconds   0.0.0.0:8081->8081/tcp, [::]:8081->8081/tcp                                                                                             schema-registry
5c3863c503fa   confluentinc/cp-enterprise-alertmanager:2.5.0              "alertmanager-start"      13 seconds ago   Up 12 seconds   0.0.0.0:9093->9093/tcp, [::]:9093->9093/tcp                                                                                             alertmanager
c3f019f94abc   confluentinc/cp-server:8.2.0                               "/etc/confluent/dock…"   13 seconds ago   Up 12 seconds   0.0.0.0:9092->9092/tcp, [::]:9092->9092/tcp, 0.0.0.0:9094->9094/tcp, [::]:9094->9094/tcp, 0.0.0.0:9101->9101/tcp, [::]:9101->9101/tcp   broker
16aeaeb34340   confluentinc/cp-enterprise-prometheus:2.5.0                "prometheus-start"        13 seconds ago   Up 12 seconds   0.0.0.0:9090->9090/tcp, [::]:9090->9090/tcp                                                                                             prometheus
```
Control Centerの起動に多少時間がかかりますが、起動後30秒程でアクセス可能になります。アドレスは http://localhost:9092 です。

![Confluent Control Center - メイン画面](/resources/control-center-main.png)

クラスタは１つのみ登録されています。（controlcenter.cluster）こちらをクリックすることによりクラスタの状態を確認できます。この時点で既にConfluent Platformとして必要なTopicが作成されますが、その他Topicは何も無い状況です。

![Confluent Control Center - Topic - 初期時](/resources/control-center-no-topic.png)

:::note info
今回のデモでは明示的にTopicを作成せず自動的に生成されるようにしております。一方、一般的にはTopic自動生成を本番環境においてOnにする事はあまり多くなく、個別に1つずつ作成します。
:::

### Kong Konnectを利用したKong Gatewayの起動
Konnectを利用してゲートウェイ (Data Plane) をローカル環境にて起動します。
![Konnect - Gateway Manager画面](/resources/konnect-main-screen.png)

まだData Planeを稼働していない状態なので、KonnectではData Planeの起動を促されます。```Configure Data Plane```ボタンをクリックしてData Planeの設定画面に移ります。

![Konnect - Data Plane Node - 新規作成](/resources/konnect-create-dp.png)

生成されたdockerの起動コマンドをローカル環境のコンソールにコピー&実行するとData Planeが立ち上がります。起動後はKonnectからその状態の確認ができます。

![Konnect - Data Plane Node - 接続完了](/resources/konnect-dp-connected.png)


## Kafkaにメッセージを送信する

### Kafka Upstreamプラグインの設定
KongではREST APIとKafkaプロトコルを変換する機能が提供されています。用途によって異なっており、Producer (REST -> Kafka) は[Kafka Upstreamプラグイン](https://developer.konghq.com/plugins/kafka-upstream/)と[Kafka Consumeプラグイン](https://developer.konghq.com/plugins/kafka-consume/)と別々に用意されています。今回は前者を利用します。

設定は[1-connect-kafka.yaml](/1-connect-kafka.yaml)に定義しています。こちらをKong Gatewayに反映させます。今回はKong Konnectから制御するアプローチを取るので、decKコマンドもKonnect用に多少アレンジが必要です。

```bash
deck gateway sync 1-connect-kafka.yaml --konnect-token $KONNECT_TOKEN
```

Konnectアクセスに必要なトークンを環境変数```KONNECT_TOKEN```に設定した後に実行します。今回のデモではデフォルトのKong Managerにて作業しますが、異なるKong Managerを指定する場合には：

```bash
deck gateway sync 1-connect-kafka.yaml --konnect-token $KONNECT_TOKEN --konnect-control-plane-name $TARGET_GATEWAY
```

となります。結果、```/kafka```というRESTのエンドポイントがゲートウェイ上に出来、ここにRESTリクエストを送信すると立ち上がっているKafkaにプロトコル変換の上送信されます。

### Insomniaを使ったREST APIリクエストの送信
新たに設定されたエンドポイントには普通にRESTリクエストを送る事が可能ですが、今回はKafka側での集約やマテリアライズを併せて検証したいので、ある程度バリエーションのあるAPIコールを作れるようにInsomnia Collection ([insomnia-collection.yaml](/Insomnia-collection.yaml))としてまとめています。

![Insomnia - Standard Format](/resources/insomnia-standard-format.png)

faker.jsを使ってIDや名前等を生成していますが、集計用に2つ留意すべき項目があります。

- day - 月曜日から日曜日まで、ランダムに生成します。後にこの値をキーとして、曜日毎の集計値を算出するのに使います。
- score - テストスコアを想定したもので、0から100までのランダムな整数が設定されます。こちらも集計値の算出に使います。

```score```の値はInsomniaのFaker機能では設定が難しい為、Scriptとして算出したものを参照しています。

![Insomnia - Scriptによるテストデータ生成](/resources/insomnia-script.png)

Producer観点では、Kafkaへの書き込みが完了するとその結果が返されますが、Ackであるため実際どのようなメッセージとしてKafkaに書き込まれたかまでは返ってきません。Kafka側で確認する必要があります。

### Control Centerで確認
Kafka Upstreamプラグインでは、メッセージ転送先Topicの名前を```source```としていました。Kong経由でこのTopicにメッセージを送った結果、新たにTopicが生成されます。
![Control Center - Topic - 新しいTopicが生成](/resources/control-center-new-topic.png)

しかしながら、メッセージは送れたものの、キーとして何も指定していないためKeyは空の状態で送られました。
![Control Conter - Topic - Keyが空](/resources/control-center-topic-no-key.png)

今回の処理では、曜日(```day```)毎に集計したいので、この値をKeyにも設定する必要があります。

新たに、メッセージの特定フィールドの値をKeyにもセットする設定を適用します。

```bash
deck gateway sync 2-add-key.yaml --konnect-token $KONNECT_TOKEN
...
updating plugin kafka-upstream for route route-kafka  {
   "config": {
     "allowed_topics": null,
...
     "keepalive_enabled": false,
-    "key_query_arg": null,
+    "key_query_arg": "kafka_key",
     "message_by_lua_functions": [
       "return function(message)
  return message.body_args
end
"
     ],
...
 }

creating plugin pre-function for route route-kafka
Summary:
  Created: 1
  Updated: 1
  Deleted: 0
```

```message_by_lua_functions```として```kafka_key```という新たな値を参照しており、併せて新しいプラグインが追加されています。このプラグインは[Pre Functionプラグイン](https://developer.konghq.com/plugins/pre-function/)であり、その定義の中でペイロードから```kafka_key```の値を設定しています。

```bash
    plugins:
    - config:
        access:
        - |
          local body = kong.request.get_body()
          if body and body.day then
            kong.service.request.set_query({ kafka_key = body.day })
          end
      enabled: true
      name: pre-function
```

適用後、```day```の値がKafka Keyにも設定されます。
![Control Center - Topic - キーが設定される](/resources/control-center-with-key.png)

## KSQLを使ったストリーム処理
RESTリクエストがKafkaに書き込まれるようになりましたが、このデータを集計するためにはプラス処理が必要です。Consumer側で処理/加工の上、DB等を使った永続化の仕組みと組み合わせた開発が必要となります。

Kafkaの場合、メッセージをConsumeして処理をするだけで無く、Kafkaを使ってデータ処理やマテリアライズ化が可能なアプローチがいくつか存在します。この方法を活用すると、ある程度のデータの集計や加工、マテリアライズ化もKafka上で行う事ができるので、そのデータを消費するConsumer側の対応がかなり容易になります。

![Kong to Kafka to KSQL](/resources/kong-kafka-ksql-diagram.png)

今回はKSQL (正式にはKslqDB) という、Kafka標準の仕組みを使ってKafka上でデータを加工します。具体的には

- データを平日 (Weekday) と 休日 (Weekends) に分けて保存。
- データをストリーム化し、SQL (に近い構文で) 加工。
- 加工データをマテリアライズ。併せて対象データに対する集計。

という流れのストリーム処理フローを作成します。

### データを平日と休日に分割
