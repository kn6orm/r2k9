# r2k9
r2k9 assistive robot

docker build -t r2k9_node .


docker run -it --rm r2k9_node

docker run -it --rm --net=host r2k9_node cmd
