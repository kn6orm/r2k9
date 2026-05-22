# r2k9 assistive robot

## Installation

### Control app

Build and run the control app

```
TARGET=chrome
cd r2k9ui
flutter build $TARGET
flutter run $TARGET
```

### r2k9 ROS2 node

```
cd docker
docker build -t r2k9_node .
docker run -it --rm --net=host r2k9_node cmd
```

## Operation

Find the URL of the webhooks TODO

```
docker run -it --rm --net=host r2k9_node TODO
```

## Development

The password is `r2k9`

## TODO

Look into using Zenoh instead of webhooks.


