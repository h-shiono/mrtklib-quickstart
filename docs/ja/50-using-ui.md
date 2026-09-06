# UI の使い方

<!-- Reading the convergence curve (OS-independent, the educational core). -->

## Real-time PPP 測位処理の実行 {#sec-run-ppp}

### 設定ファイルの読み込み {#sec-run-ppp-load-preset}

栞のアイコンをクリックすると、Preset が開きます。

`QZSS MADOCA (BUILT-IN)` と書かれた Preset を読み込みます。
`Load preset will overwrite current settings. Continue?` と聞かれるので、`Load` をクリックして読み込みます。

![](../assets/img/mrtklib-preset.png)

読み込みに成功すると `"QZSS MADOCA (PPP-Kinematic)" loaded` と表示されます。

### ローバの設定 {#sec-run-ppp-configure-rover}

`Input Streams` > `Rover` に、次の値を設定します。

<figure class="md-table-figure" markdown id="tbl-setup-rover">
<figcaption>ローバの設定</figcaption>

| 項目 | 設定値 |
| --- | --- |
| Type | Serial |
| Path | `ttyACM0` |
| Format | Septentrio SBF |

</figure>

![](../assets/img/mrtklib-rover-setup.png)

!!! note "ノート"

    `Path` は常に `ttyACM0` です。受信機のどちらの仮想 COM ポートから SBF が出ていても、起動スクリプトがコンテナ内では `/dev/ttyACM0` として見えるように渡すため、環境によって書き換える必要はありません。
    先頭の `/dev/` は不要です。

### 測位処理の実行 {#sec-run-ppp-start}

`Start` をクリックして測位処理を開始します。
初回実行時は、航法データの取得が必要なため測位がはじまるまで少し時間がかかります。

![](../assets/img/mrtklib-madoca-ppp.png)

広域電離圏補正により、条件が良ければ数分で FIX 解が得られます。

### Chart の切り替え {#sec-run-ppp-chart}

`Chart` は `2D` / `Map` / `Sky/SNR` / `Time series` をクリックで表示・非表示することが可能です。

![](../assets/img/mrtklib-madoca-ppp-chart.png)

### 測位パラメータの確認 {#sec-run-ppp-processing-config}

`Processing Configuration` の各項目をクリックすると、測位パラメータの詳細を確認することが可能です。

![](../assets/img/mrtklib-madoca-ppp-positioning-mode.png)

## 以上で MADOCA-PPP の体験は完了です 🎉

体験を終えるときは、[終了処理（Windows）](60-stop-windows.md) を行いコンテナの停止と USB のデタッチを行ってください。

!!! tip "ヒント"

    日本国内で本チュートリアルを実行されているかたは、`QZSS CLAS (BUILT-IN)` と書かれた Preset を読み込むことで、CLAS (PPP-RTK) の測位もお試しいただくことができます。
    ぜひ、MADOCA-PPP との違いを体験してみてください。

    ![](../assets/img/mrtklib-clas.png)

さらに学びたい方は、以下のリンクを参考にしてください。

- [みちびき Web](https://qzss.go.jp/index.html)
- [Septentrio mosaic-G5 P6](https://www.septentrio.com/ja/products/gnss-receivers/gnss-receiver-modules/mosaic-G5-P6)
    - 評価キット
        - 🇯🇵: [※4周波コンパス&RTKフル機能小型モジュール](https://shop.cqpub.co.jp/hanbai/books/I/I100637.htm)
        - 🇬🇧: [mosaic-go G5 P6 GNSS module receiver evaluation kit](https://shop.septentrio.com/en/shop/mosaic-go-g5-p6-gnss-module-receiver-evaluation-kit)
- MRTKLIB:
    - [MRTKLIB](https://github.com/h-shiono/MRTKLIB)
    - [mrtklib-docker-ui](https://github.com/h-shiono/mrtklib-docker-ui)
    - [mrtklib-quickstart](https://github.com/h-shiono/mrtklib-quickstart)
    - [Zenn (hato.GNSS)](https://zenn.dev/hatognss)（MRTKLIB メンテナの技術記事）

## うまくいかない場合

- [トラブルシューティング](90-troubleshooting.md)
