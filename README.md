# 使用 RasaNLU 构建自己的 NLU 服务

[TOC]

## 前置知识

我们生活在机器学习技术突飞猛进的时代，我们都憧憬能够学习一切的强人工智能的出现，我们都知道，有强人工智能和没有它的时代，一定会是截然不同的两个世界。然而令人沮丧的是，强人工智能所依赖的基础科学还有很多亟待攻克的难题。但是，我们根据**实验室**里流出的技术、和**工程界**前人做出的轮子，我们可以大致拼凑出未来人工智能的图景，管中窥豹地预览一下未来和人工智能对话的图景。

ChatBot 不是真正的人工智能，但这不影响我们利用现有的机器学习技术，来构建一个可以通过自然语言与用户沟通、并且提供实用功能的机器人。

为了制作 ChatBot 或者类似 Siri 这样的聊天机器人，需要使用自然语言理解的技术。确切的说，在 ChatBot 场景下，我们具体的技术需求是：

- 处理较短的文本
- 识别提问者的意图
- 提取有效信息

短文本，是需求所在；意图识别，有 `tensorflow`、`scikit-learn` 中强大的分类器可以用；信息提取，`MITIE` 也整合了很多有效的算法。最后把它们串在一起的，是 `Rasa` 的工程师，他们把制作一个能说会道的 ChatBot，庖丁解牛般拆解成了可以实现的子问题：

- 将短文本的处理过程，做成一条流水线（pipeline），开发者可以任选他们喜欢的分类器、分词引擎等
- 将对话的过程，使用 markdown 的语法来表述，并实现了多轮对话中的关键信息保持
- 将标注意图和信息要素的任务，让开发者编写 markdown 即可完成

所谓好人做到底，他们还顺便实现了一个用 python 框架 `twisted` 编写的 WebServer，把提问语句放到 HTTP 请求里，就能返回包含意图和有效信息的 JSON 串。

根据手上的东西，经过一番实践之后，我发现只需编写爬虫爬一些语料提前做好 word embedding、再手工标注一些语料、最后再整理一些 dockerfile 和 makefile 出来，就能把 `自然语言理解服务的架设` 变成令人舒适的自动化的过程，也就是本项目能带给你的东西。

之前写过[一篇文章](https://yicongcao.github.io/2018/12/25/%E7%9F%AD%E6%96%87%E6%9C%AC%E7%90%86%E8%A7%A3%E7%9A%84%E5%B7%A5%E7%A8%8B%E5%AE%9E%E8%B7%B5/)，当时还是直接 fork 人家代码线然后做的修改，并不是编码上的最佳实践。这次我把 配置文件、语料模型、Rasa源代码，都分离开，可以比以前更方便地，仅通过一套代码，就能训练出多套不同产品的 NLU 服务，把它们容器化，可以直接丢到 K8s 集群上运行。

## 食用方法

```bash
# 构建方式
# 1. 先构建包含RasaNLU本体的基础镜像
cd ./RasaNLUPack
make build-base-env
# 2. 再构建game_nlu项目所用的NLU服务镜像
make build-proj-env PROJ_NAME=game_nlu
# 也可以合成一步操作，直接构建出最后可用的NLU服务镜像
make build-all PROJ_NAME=game_nlu

# 四种用法
# 1. 训练模型: 拉起镜像，在容器中训练模型，并保存到宿主机的models目录
make train-out PROJ_NAME=game_nlu
# 2. 运行服务: 拉起镜像，使用models目录下自带的模型，运行NLU服务的webserver
make server PROJ_NAME=game_nlu
# 3. 运行服务Ex: 拉起镜像，在容器中训练模型，保存到容器内，然后使用该模型运行NLU服务的webserver
make train-and-server PROJ_NAME=game_nlu
# 4. 探索容器: 拉起镜像，进入bash，可以做任何事情
make bash PROJ_NAME=game_nlu

# 自测服务
make test Q=塞尔达传说好玩吗

{
  "intent": {
    "name": "queryrating",
    "confidence": 0.38768090380324954
  },
  "entities": [
    {
      "entity": "name",
      "value": "塞尔达传说",
      "start": 3,
      "end": 7,
      "confidence": null,
      "extractor": "MitieEntityExtractor"
    }
  ],
...

# 停止服务
# 再开一个terminal进到当前目录执行stop
make stop PROJ_NAME=game_nlu

# 导出镜像
# 将镜像保存到父目录，可以直接上传到蓝盾K8s
make export PROJ_NAME=game_nlu
```

我的目标是将模型的训练容器化，而不是要求宿主机要配置一堆繁杂的完整环境。

将构建镜像给拆成两步，好处是：

- 快速调试，当语料需要频繁调整时，只需要从第二阶段重新构建项目镜像即可，可以很快构建出可用镜像
- 版本一致，第一次构建出基础镜像之后，你的环境就不受 tensorflow、scikit-learn 等框架更新的影响

将展开服务拆成三种用法，好处是：

- 我可以把在本机训练好的模型，直接拿到服务器上去跑，那么可以先执行 `train-out`，将模型保存到宿主机，然后执行 `build-proj-env` 从第二步重新构建项目镜像，把训练好的模型包含进去。那么构建出的镜像，运行起来就能直接提供 NLU 服务，无需再做训练，这时可以在本机执行 `server` 操作测试接口，没问题之后，执行 `export` 导出镜像，直接上传到蓝盾 Kubernetes 集群上运行
- 也可以直接在容器中对模型进行训练、训练好了之后直接拉起webserver，提供 NLU 服务。这种可以直接直接执行 `train-and-server` ，稍坐片刻就能测试 NLU 接口了
- 如果models目录下有已经训练好了的模型，直接执行 `server` 即可拉起webserver，运行 `test` 即可测试接口可用性
- 如果只是想进入构建好的容器，像虚拟机那样来执行命令、看看有什么东西，那么执行 `bash` 即可进入容器，你可以将自己写的 `python` 代码一起构建到容器里，然后这样进去执行和调试，基于 RasaNLU 二次开发出更优秀的产品

个人觉得第一种用法最好，这个例子中标注的语料，在 6核 16GB 的 MacBook Pro 2018’ 上只需要 5分钟 就能训练完成。所以倾向于保存下来训练好的模型、构建出包含该模型的项目镜像、然后直接扔到集群上提供服务。我在 dockerfile 中默认写的 `ENTRYPOINT`，也是直接执行 `server` 来加载现成的模型、然后拉起 webserver。

## 代码结构

```yaml
├── Makefile
├── Makefile_for_container
├── README.md
├── dockerfiles
│   ├── Dockerfile_game_nlu_step2
│   ├── Dockerfile_game_nlu_step2
│   └── Dockerfile_rasa_nlu_step1
├── models
├── nluconfig
│   ├── config_game_nlu.yml
│   └── config_game_nlu.yml
├── traindata
│   ├── game_nlu
│   │   ├── demo-rasa_zh_game.json
│   │   └── demo-rasa_zh_game.md
│   └── game_nlu
│       ├── demo-rasa_zh_game.json
│       └── demo-rasa_zh_game.md
├── userdict
│   ├── game_nlu
│   │   └── game_names.txt
│   └── game_nlu
│       └── lego_res.txt
└── wordembedding
    ├── total_word_feature_extractor_game.dat
    └── total_word_feature_extractor_zh.dat
```

两则 `Makefile`，默认的是用于在宿主机上调试的，带后缀的是用于在容器内接受命令的。

`dockerfiles` 目录包含构建第一阶段、第二阶段的基础镜像、项目镜像所需的配置文件。

`models` 目录是执行 `train-out` 命令默认的模型输出路径，构建第二阶段项目镜像时，如果这个目录下有训练好的模型，那么可以在容器里直接加载并开始使用（在容器内的挂载路径是 `/opt/rasa`）。

`nluconfig` 目录包含 RasaNLU 所用的流水线（pipelines）配置文件。

`traindata` 目录包含标注的意图文件，默认只使用 markdown 版本，json 版本仅用来参考。

`userdict` 目录包含结巴分析所需的词典，事先放了乐高游戏里的资源名、和从 VGTime 爬取的主机游戏名作为参考。

`wordembedding` 目录包含使用 MITIE 提前训练好的 word embedding 模型。这个目录下的文件比较大，**无法**上传到 Git 上面，如果需要的话，请联系我来索取。这里有两个，分别是使用维基百科全站语料训练出来的、和使用VGTime上近三年的游戏新闻训练出来的。

另外读者可能注意到了，这些配置里经常出现 `game_nlu` ，这个是工程名。我认为在使用的脚本种类比较多、配置文件也很多的情况下，在组织这些文件的时候，至少要采用一致的工程名。如果查看我写的 makefile 源码，能发现里面没有直接写死引用 主机游戏搜索 和 乐高资源推荐 这两个项目配置文件的路径，而是引用调用 `make` 命令时传入的 `PROJ_NAME` 字段。所以建议大家也这样组织配置文件，来实现一份源码、可以生成多份 NLU 服务镜像。或者大家有更好的实践方法、或者看出了我这个 30分钟入门 makefile 和 shell 脚本 时所露出的马脚，欢迎拍砖👏

## 一些想法

从客户端转后台半年来，每天都能学到新知识，现在头脑中有强烈的几个想法，请一定要打醒我：

- 容器化比裸机运行更好
- 自动编排比人工运维更好
- 集中管理比分散存储更好（代码结构上）
- 微服务比大而全更好（服务部署上）
- 技术可以差，Terminal 必须骚！

![Terminal Theme](https://ws1.sinaimg.cn/large/006tKfTcgy1g1bucmaetmj30tf0kb1h5.jpg)

![Test NLP](https://ws3.sinaimg.cn/large/006tKfTcgy1g1buet9taej30t80cx4c0.jpg)

May the force be with you : )