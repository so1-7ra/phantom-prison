# Phantom Prison

幽霊が囚われた刑務所から、霊を封じた瓶を**静かに**運び出す回収ホラーゲームです。
全クリはありません。夜ごとに上がるノルマを、何夜目まで達成し続けられるかを競います。

企画の詳細は [docs/GDD.md](docs/GDD.md) を参照してください。

## 遊び方（試作版 M2）

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
| 一時停止（設定・タイトルへ） | Esc |

- 霊瓶は揺らす・ぶつける・投げると**封印**が弱まり、0 になると幽霊が逃げ出して襲ってきます
- 緑に光る**搬出口**に霊瓶を運び込むと売れます。封印が多く残っているほど高く売れます
- 3 分以内にノルマを達成できないと「収監」されてゲームオーバーです
- 設定画面で、マウス感度・音量・画面の粗さ（PS1 風の度合い）・フルスクリーンを変えられます

## 難易度の調整

Godot のファイル一覧で `data/balance.tres` を選ぶと、右側のインスペクタに
ノルマ・制限時間・霊瓶の価値と壊れやすさ・幽霊の速さなどがまとめて表示されます。
数値を変えて F5 で遊ぶだけで、コードを触らずに手触りを調整できます。

## フォルダ構成

```
scenes/main.tscn            入口のシーン（中身はほぼコードで組み立てる）
scripts/main.gd             夜のループ、ノルマ、ゲームオーバー、記録の保存、低解像度描画
scripts/menu.gd             タイトル・一時停止・ゲームオーバー・設定の画面
scripts/config.gd           プレイヤー設定の保存と反映（Autoload「Config」）
scripts/game_balance.gd     調整用パラメータの定義（値は data/balance.tres）
scripts/level_generator.gd  刑務所のランダム生成
scripts/flicker_light.gd    明滅する蛍光灯
scripts/player.gd           一人称の移動、掴む・投げる、足音
scripts/ghost_jar.gd        霊瓶と封印の仕組み
scripts/ghost.gd            幽霊の動き
scripts/extraction_zone.gd  搬出口
scripts/hud.gd              画面表示
scripts/sfx.gd              効果音をコードで合成する
shaders/ps1_world.gdshader  壁・床の PS1 風シェーダー（頂点のガタつき、ぼかさないテクスチャ）
shaders/ps1_post.gdshader   画面全体の仕上げ（減色、ディザ、周辺減光）
fonts/                      DotGothic16（SIL Open Font License。fonts/OFL.txt を参照）
tests/smoke_test.gd         ヘッドレスでタイトルから一晩の流れまでを確認するテスト
```

## テスト

```sh
godot --headless --editor --quit --path .   # 初回のみ：クラス名の情報を作る
godot --headless --fixed-fps 60 --path . -s tests/smoke_test.gd
```
