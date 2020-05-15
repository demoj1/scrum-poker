#! /usr/bin/env bash

docker build . -t poker
docker create -ti --name poker poker bash
docker cp poker:/app/_build/prod/rel/poker ./app 
docker rm -f poker