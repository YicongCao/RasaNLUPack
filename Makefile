# 这是给宿主调试用的 makefile

.PHONY: clean train-nlu train-core cmdline server

TEST_PATH=./
PROJ_NAME=$(PROJ_NAME)
MODEL_PATH_ABSOLUTE=$$(pwd)"/models"

# 示例 PROJ_NAME
# PROJ_NAME=lego_nlu

check-proj-name:
	test $(PROJ_NAME)

check-question:
	test $(Q)

help:
	@echo "    build-base-env"
	@echo "        构建基础镜像，包含 Rasa_NLU 和 训练中文模型需要的包."
	@echo "    build-proj-env"
	@echo "        构建项目镜像，指定需要的配置文件名"
	@echo "    build-all"
	@echo "        构建基础镜像，然后接着构建项目镜像"
	@echo "    train-out"
	@echo "        在本机训练NLU模型，输出到models目录."
	@echo "    server"
	@echo "        在本机5005端口开放NLU服务，使用自带模型."
	@echo "    train-and-server"
	@echo "        在本机5005端口开放NLU服务，先在容器内进行训练."
	@echo "    stop"
	@echo "        停止当前运行的项目容器."
	@echo "    PROJ_NAME=lego_nlu"
	@echo "        设定你自己的工程名，否则会报循环引用错误."

clean: check-proj-name
	@echo "正在删除训练好的模型"
	rm -rf models/$(PROJ_NAME)

build-base-env:
	docker build -t rasanlu_base -f ./dockerfiles/Dockerfile_rasa_nlu_step1 .

build-proj-env: check-proj-name
	docker build -t $(PROJ_NAME) -f ./dockerfiles/Dockerfile_$(PROJ_NAME)_step2 .

build-all:  check-proj-name build-base-env build-proj-env

train-out: check-proj-name
	if [ ! -d "./models" ]; then mkdir models; fi
	docker run -it --rm --entrypoint "make" --mount type=bind,source=$(MODEL_PATH_ABSOLUTE),target=/opt/rasa $(PROJ_NAME) train-out -f Makefile_for_container PROJ_NAME=$(PROJ_NAME)

server: check-proj-name
	docker run -it --rm --name $(PROJ_NAME)_instance -p 5005:5000 $(PROJ_NAME)

bash: check-proj-name
	docker run -it --rm --name $(PROJ_NAME)_instance -p 5005:5000 --entrypoint "bash" --mount type=bind,source=$(MODEL_PATH_ABSOLUTE),target=/opt/rasa $(PROJ_NAME)

train-and-server: check-proj-name
	docker run -it --rm --name $(PROJ_NAME)_instance -p 5005:5000 --entrypoint "make" $(PROJ_NAME) train-and-server -f Makefile_for_container PROJ_NAME=$(PROJ_NAME)

stop: check-proj-name
	# docker rm $(docker stop $(docker ps -a -q --filter ancestor=legonlu --format="{{.ID}}"))
	docker container kill $$(docker ps --filter ancestor=$(PROJ_NAME)|awk '{if(NR==2) print $$1}')

export: check-proj-name
	docker image ls | grep $(PROJ_NAME)
	docker save -o ../$(PROJ_NAME)_latest.tar $(PROJ_NAME):latest

test: 
	curl http://127.0.0.1:5005/parse?q=$(Q)