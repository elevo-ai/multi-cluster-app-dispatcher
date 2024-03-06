# Instructions to build foresight/multi-cluster-app-dispatcher for Aizen Foresight

## One time setup

### Dependencies
  - Install Go (version 1.20)
  ```
  dnf install golang-bin
  ``` 
  - Install make

## Build mcad
- git clone elevoai/multi-cluster-app-dispatcher
- Execute script
```
./build_foresight_mcad.sh
```
Executable will be created in _output directory in the current folder and foresight-mcad-contoller image pushed to Aizen repository