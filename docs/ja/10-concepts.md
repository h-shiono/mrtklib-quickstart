# コンセプト

<!-- What MADOCA-PPP is, where it sits among positioning methods, and why it
     converges the way it does. Assumes a positioning-literate reader. -->

## MADOCA-PPP とは {#sec-about-madoca-ppp}

**MADOCA-PPP (Multi-GNSS Advanced Orbit and Clock Augmentation - Precise Point Positioning)**は、準天頂衛星システム（QZSS）の L6 信号から配信される補正情報の一つです。
仰角10度以上の QZS が1機以上、仰角10度以上の補強対象衛星が20機以上見える範囲で利用可能です。

<figure markdown="1" id="fig-madoca-ppp-service-area">
![MADOCA-PPP サービス範囲](../assets/img/madoca-ppp-service-area.jpg)
<figcaption markdown="span">MADOCA-PPP サービス範囲[^1]</figcaption>
</figure>

[^1]: 高精度測位補強サービス（MADOCA-PPP）, QSS, https://qzss.go.jp/technical/system/madoca.html, 2026-07-15 アクセス 

MADOCA-PPP の補正情報を用いることで、精密単独測位（Precise Point Positioning）を行うことができ、センチメータ級の測位精度が得られます。
サービスは L6E 信号から配信され、衛星の軌道・クロック・バイアスの補正情報が含まれています。
補強対象となる GNSS は GPS, GLONASS, Galileo, BeiDou, QZSS です。
用いるアルゴリズムにもよりますが、数十センチ～センチメータ級の精度が得られるまで30分程度要します。

2025年より、QZSS の7機体制の整備がはじまりました。
これに伴い、**QZS6, QZS7 の L6D 信号から広域電離圏補正情報が配信**されることになりました。
従来の L6E 信号と併せて用いることで、収束時間を**10分程度**まで縮めることが可能になりました。

<figure markdown="1" id="fig-madoca-ppp-iono-service-area">
![MADOCA-PPP 広域電離圏補正 サービス範囲](../assets/img/madoca-ppp-service-area-iono.png)
<figcaption markdown="span">MADOCA-PPP 広域電離圏補正 サービス範囲[^2]</figcaption>
</figure>

[^2]: Coverage area of MADOCA-PPP ionospheric correction data, QSS, https://qzss.go.jp/en/technical/download/pdf/ps-is-qzss/Coverage%20area%20of%20MADOCA-PPP%20ionospheric%20correction%20data_20250714.pdf, 2026-07-16 アクセス

!!! danger "重要"

    広域電離圏情報配信については、現在技術実証中です。
    詳細は下記 Service Level Information をご覧ください。

    [Quasi-Zenith Satellite System Service Level Information for Multi-GNSS Advanced Orbit and Clock Augmentation – Precise Point Positioning Technology Demonstration (Ionospehric Correction) (SLI-MDC-ION, Draft)](https://qzss.go.jp/en/technical/download/pdf/ps-is-qzss/sli-mdc-ion-draft.pdf)（2022年2月）

    加えて 2026-08-30 時点では、日本を覆う L6D を配信する QZS7（[各 QZS 衛星と高精度測位サービス](#tbl-qzs-has)）が搭載機器の機能確認中で、**まだ信号を送信していません**[^3]。
    日本国内では広域電離圏補正を受信できないため、収束は MADOCA-PPP 単独の約 30 分となります。
    フィリピン・インドネシア・オーストラリア西部では、QZS6 からの配信を利用できます。

本ガイドを通して、この MADOCA-PPP 広域電離圏補正サービスを体験していただきます。

## QZSS が配信する補正情報とその位置づけ {#sec-qzss-corrections}

QZSS の L6 信号からは2種類の補正情報が配信されています。
一つはセンチメータ級測位補強サービス（CLAS）で、日本全土をカバレッジとし、約 1 分でセンチメータ級の精度が得られるのが特徴です。
そしてもう一つが MADOCA-PPP で、QZSS 可視域（アジア・オセアニア）をカバレッジとし、数十分でセンチメータ級の精度が得られるのが特徴です。
2つに共通するのは、補正情報を**通信回線ではなく QZSS からの衛星配信で受け取る**点にあります。
基準局や携帯回線を用意しなくても、受信機単体で精密測位を始められます。

<figure class="md-table-figure" markdown id="tbl-comp-pos-algorithm">
<figcaption>高精度測位手法の比較</figcaption>

| 測位手法 | 補正の配信 | カバレッジ | 収束（目安） | 通信インフラ |
| --- | --- | --- | --- | --- |
| RTK | 基準局との通信 | 基線 ~10 km | 数秒 | 要 |
| ネットワーク RTK (VRS) | 基準局ネットワークとの通信 | 地域（ネットワークの範囲） | 数秒 | 要 |
| CLAS (PPP-RTK) | QZSS 衛星配信 (L6D) | 日本国内 | 約 1 分 | 不要 |
| **MADOCA-PPP** | QZSS 衛星配信 (L6E) | QZSS 可視域（[サービス範囲](#fig-madoca-ppp-service-area)） | 約 30 分 | 不要 |
| **MADOCA-PPP + 広域電離圏補正** | QZSS 衛星配信 (L6E + L6D) | 広域（[サービス範囲](#fig-madoca-ppp-iono-service-area)） | **約 10 分** | 不要 |

</figure>

RTK / ネットワーク RTK は瞬時にセンチメータ級の精度が得られますが、基準局との距離に制約があり、かつ補正情報を受信するための通信回線が別途必要です。
CLAS (PPP-RTK) は RTK と PPP の中間に位置する技術で、PPP ほどの広域はカバーしないものの、RTK より広いエリアで RTK 並みの収束性が得られるのが特徴です。

MADOCA-PPP は衛星配信のみで広域をカバーできる代わりに収束に時間がかかる、というトレードオフです。

### QZS 衛星と高精度測位サービス {#sec-qzs-has}

各 QZS 衛星が L6 信号から配信する高精度測位サービスは[下表](#tbl-qzs-has)のとおりです。

<figure class="md-table-figure" markdown id="tbl-qzs-has">
<figcaption>各 QZS 衛星と高精度測位サービス</figcaption>

| 衛星名 | L6D PRN | L6D 配信サービス | L6E PRN |
| :----- | --- | :--- | --- |
| QZS2      | 194 | CLAS (2) | 204 |
| QZS4      | 195 | CLAS (1) | 205 |
| QZS1R     | 196 | CLAS (2) | 206 |
| QZS3      | 199 | CLAS (1(\*1), 2) | 209 |
| QZS6      | 200 | MADOCA-PPP 広域電離圏補正（フィリピン、インドネシア、オーストラリア西部） | 210 |
| QZS7(\*2) | 201 | MADOCA-PPP 広域電離圏補正（日本、オーストラリア東部） | 211 |

</figure>

- L6E は全機が MADOCA-PPP（軌道・クロック・位相バイアス補正）を配信する。
- CLAS のかっこは配信パターンを示す。
- (\*1) 通常はパターン 1 を配信するが、他の衛星が何らかの理由で長期間利用できない場合などにパターン 2 を配信することがある。
- (\*2) 2026-08-30 時点で In commissioning（試験運転中）のステータスで、搭載機器の機能確認中のため信号は未送信。
- QZS1 は QZS1R に置き換え済み。QZS5 は H3 ロケット 8 号機の打上げ失敗（2025-12-22）により喪失したため、本表には含まない[^4]。

[^3]: みちびき7号機が準静止軌道に入りました, QSS, https://qzss.go.jp/info/information/qzs7_260822.html, 2026-08-30 アクセス

[^4]: H3ロケット8号機の打上げ失敗及び準天頂衛星システム「みちびき5号機」の喪失について, QSS, https://qzss.go.jp/info/information/qzs-5_251225.html, 2026-08-30 アクセス

本ガイドで体験するのは、各機の L6E と QZS6/QZS7 の L6D を併用して収束を短縮した **MADOCA-PPP + 広域電離圏補正** です。

## Float PPP と PPP-AR/Iono {#sec-ppp-modes}

PPP の収束時間は、搬送波位相の**整数値不定性（アンビギュイティ）**をどう扱うかで大きく変わります。

- **Float PPP** — アンビギュイティを実数のまま推定する方式で、収束に数十分かかります。
- **PPP-AR (Ambiguity Resolution)** — 位相バイアス補正を用いてアンビギュイティを解く方式で、精度・収束性が向上します。MADOCA-PPP は L6E でこのバイアス補正を配信しており、PPP-AR を利用することができます。
- **PPP-AR/Iono** — さらに広域電離圏補正（L6D）を適用することでアンビギュイティ決定を後押しし、収束時間が約 10 分まで短縮されます。

本ガイドではこの **PPP-AR/Iono** を動かし、UI 上で収束の様子を観察します。

## 受信機が出力するデータ {#sec-receiver-output}

PPP エンジンは、受信機自身が測った**観測量**（擬似距離・搬送波位相）に対して QZSS L6 から届く**補正情報**を適用し、計算を行います。
本ガイドの構成では、両方を 1 本の SBF ストリーム（`Support` メッセージ群）にまとめ、受信機の `USB1` ポートから出力します。

受信機を USB で接続すると WSL 側に 2 つのシリアルポート（`/dev/ttyACM0` / `/dev/ttyACM1`）が現れますが、SBF が流れているのは一方だけで、起動スクリプトが中身を見て自動判別します。
判別したポートは、コンテナ内では常に `/dev/ttyACM0` として見えるように渡されるため、UI で設定するパスは環境によらず `ttyACM0` で固定です。
受信機側の具体的な設定は「[付録：受信機の手動設定](80-appendix-receiver-setup.md)」を参照してください（通常は `start.bat` が自動で行います）。

## 次のステップ

- はじめて起動する → OS 別のインストール
（[Windows](20-install-windows.md) / [macOS](21-install-macos.md) / [Linux](22-install-linux.md)）
- 2回目以降 → OS 別の起動
（[Windows](30-run-windows.md) / [macOS](31-run-macos.md) / [Linux](32-run-linux.md)）
