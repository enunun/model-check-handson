# Iteration 4：注文が必ず決着する(課題)

「いずれ〜する」という要求を，時相論理の性質として書き，TLCで検査する．
処理が途中で止まる実行を見つけ，止まらないために実際のシステムが約束すべきことを，公平性の仮定として決める．

## 学ぶこと

- 安全性と活性の違い．
- 時相論理の性質(`always`，`eventually`)と，公平性の仮定(`weakFair`)．
- 有界モデル検査(Apalache)と全状態探索(TLC)の使い分けと，TLCの反例の読み方．

## 進め方

[課題の手順](docs/iteration-4.md)に従って進める．
模範解答と解説は，[solution](../solution/README.md)にある．

## ファイル

| ファイル | 内容 |
| --- | --- |
| `requirements.md` | 要求文と決定事項 |
| `shop.qnt` | 仕様 |
| `shop_test.qnt` | シナリオのテスト |
| `state-diagram.md` | 仕様から生成した状態遷移図 |
| `docs/iteration-4.md` | 課題の手順 |
