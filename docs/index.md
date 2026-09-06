# mrtklib-quickstart

本ガイドでは、MRTKLIB を GUI で操作するための Docker コンテナの起動方法と、MRTKLIB と Septentrio mosaic-G5 を使って MADOCA-PPP による Real-time PPP 測位を体験するための手順を説明します。

This guide explains how to start the Docker container for operating MRTKLIB via a GUI, and how to experience real-time positioning with MADOCA-PPP using MRTKLIB and the Septentrio mosaic-G5.

!!! note "ノート / Note"

    本ガイドでは、Septentrio 社の mosaic-G5 受信機を使用することを前提としています。

    This guide assumes that you are using the **Septentrio mosaic-G5** receiver.

ヘッダーの :material-translate: から言語を選べます。

Use :material-translate: in the header to choose a language.

## クイックスタートガイド / Quick-start guide

初期設定済みの Docker コンテナを使って、MRTKLIB を GUI で操作するまでの手順を順を追って解説します。はじめての方・手順を確認しながら進めたい方はこちら。

A step-by-step guide to operating MRTKLIB via its GUI using a preconfigured Docker container. Start here if this is your first time.

<div class="grid cards" markdown>

-   🇯🇵 __日本語__

    ---

    Docker コンテナを使って、MRTKLIB を GUI で操作するまでの手順。

    [:octicons-arrow-right-24: ガイドを開く](ja/00-overview.md)

-   🇬🇧 __English__

    ---

    Step-by-step guide to operating MRTKLIB via its GUI with Docker.

    [:octicons-arrow-right-24: Open the guide](en/00-overview.md)

</div>

## まず動かしたい方へ / Just run it first

準備が整っていて最短で起動したい方は、お使いの OS のスクリプトを実行してください。手順の詳細は各言語ガイドの「起動」章を参照してください。

If you are already set up and just want the fastest path, run the script for your OS. For step-by-step details, see the "Run" chapter in the language guide (cards above).

- Windows: `scripts/windows/start.bat`
- macOS: `scripts/macos/start.command`
