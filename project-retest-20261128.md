# 云上凭据泄露检测项目方复测 · 2026-11-28

本轮在项目自有公开仓库发布从未签发的合成制品。匿名观察端先读取干净基线，再记录每个版本最后不可见和首次可见的时间。下表按保守时延上界统计。

| 入口 | 正式发布 | 正确定位 | 规定时间内检出 | 本轮最大时延上界 |
| --- | ---: | ---: | ---: | ---: |
| OCI 镜像 | 3 | 3 | 3/3（180 秒） | 14.149 秒 |
| 签名 APK | 3 | 3 | 3/3（180 秒） | 31.394 秒 |
| 临时 MediaWiki | 24 | 24 | 24/24（120 秒） | 59.885 秒 |

OCI 与 APK 各测试一份操作系统密码、数据库密码和 OAuth Client Secret。逐份核对不可变版本、包内路径、行号及类型，并重新下载三个镜像层和三个 APK 核对字节。两个专项各有三个新版本，历史全量验收仍为 144 次发布、142 次按时。[发布记录 1](https://github.com/ziyil55333-dotcom/cloud-credential-watch-public-fixtures/actions/runs/46150663000) · [发布记录 2](https://github.com/ziyil55333-dotcom/cloud-credential-watch-public-fixtures/actions/runs/46150715505) · [发布记录 3](https://github.com/ziyil55333-dotcom/cloud-credential-watch-public-fixtures/actions/runs/46150851040)

本轮 MediaWiki 使用新建临时站点重放既有的 24 份合成样本。作业在线期间读回 26 个修订，含一份干净基线及一份清理修订。26 份原文与发布作业的 XML 导出逐字节相符。[MediaWiki 作业](https://github.com/ziyil55333-dotcom/cloud-credential-watch-public-fixtures/actions/runs/46150975426)

Git 处置演示命中专用文件第 2 行的 API Key，保守时延上界 3.438 秒。清理后从公开地址核对，当前版本已移除样本，原提交仍可追溯。处置记录经重启仍为“已复查”。[样本提交](https://github.com/ziyil55333-dotcom/cloud-credential-watch-public-fixtures/commit/f0c9825eb7112efaaf0f9973de172d4511acd27d) · [清理提交](https://github.com/ziyil55333-dotcom/cloud-credential-watch-public-fixtures/commit/1a0e18ffae9a5696a03570d0eb375050b50d13a4)

本轮由项目方执行。独立六入口盲测仍缺投放与首轮记录。现有证据可确认内部评分 60 分，完整总分留空。
