# Phantom Prison

幽霊が囚われた刑務所から、霊を封じた瓶を**静かに**運び出す回収ホラーゲームです。
全クリはありません。夜ごとに上がるノルマを、何夜目まで達成し続けられるかを競います。

企画の詳細は [docs/GDD.md](docs/GDD.md) を参照してください。

## 遊び方（試作版 M1）

1. [Godot 4.3](https://godotengine.org/download) 以降をインストールする
2. Godot でこのフォルダの `project.godot` を開き、F5 で実行する

| 操作 | キー |
|---|---|
| 移動 | WASD |
| ダッシュ | Shift |
| ジャンプ | Space |
| 霊瓶を掴む・離す | E または 左クリック |
| 投げる | 右クリック |
| 夜を終える（ノルマ達成後、搬出口で） | F |
| やり直す（ゲームオーバー後） | R |
| マウスカーソルを解放する | Esc |

- 霊瓶は揺らす・ぶつける・投げると**封印**が弱まり、0 になると幽霊が逃げ出して襲ってきます
- 緑に光る**搬出口**に霊瓶を運び込むと売れます。封印が多く残っているほど高く売れます
- 3 分以内にノルマを達成できないと「収監」されてゲームオーバーです

## フォルダ構成

```
scenes/main.tscn          入口のシーン（中身はほぼコードで組み立てる）
scripts/main.gd           夜のループ、ノルマ、ゲームオーバー、記録の保存
scripts/level_generator.gd 刑務所のランダム生成
scripts/player.gd         一人称の移動、掴む・投げる
scripts/ghost_jar.gd      霊瓶と封印の仕組み
scripts/ghost.gd          幽霊の動き
scripts/extraction_zone.gd 搬出口
scripts/hud.gd            画面表示
tests/smoke_test.gd       ヘッドレスで一晩の流れを確認するテスト
```

## テスト

```sh
godot --headless --editor --quit --path .   # 初回のみ：クラス名の情報を作る
godot --headless --fixed-fps 60 --path . -s tests/smoke_test.gd
```
