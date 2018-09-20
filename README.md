# redisniffer [![Build Status](https://travis-ci.org/maiha/redisniffer.svg?branch=master)](https://travis-ci.org/maiha/redisniffer)

Sniff redis packets and summarize count of commands.

- x86_64 binary: https://github.com/maiha/redisniffer/releases

## Usage

Needs `root` user or privilege to the device.

```shell
% redisniffer
listening on lo about '(tcp port 6379)' (snaplen: 1500, timeout: 1000)
output: Stdout
[6379, {"PING" => 1}, nil]
[6379, {"GET" => 1}, nil]
```

## Options

- `-p 6379,7001,7002` : capture port
- `--deny MONITOR,PING` : these cmds are not stored in stats
- `--include-ip` : stores client ip addresses too
- `-o redis://localhost:6379` : write stats into redis
- `-o file://cmds.log` : write stats into file

See `redisniffer --help` for more options

## Redis output

`-o` option enables you to store stats in redis.

```shell
% redisniffer -i eth0 -p 6379 -o redis://localhost:6000 --out-interval 60
```

This watches `6379` port on `eth0` and writes stats into redis(port=6000) as `ZSET` every minute.

#### redis:6000

Three `ZSET` entries related to the time will be updated.

- "6379/20170322"
- "6379/2017032217"
- "6379/201703221737"

Thus, we can easily get cmd stats by `ZRANGE` about three kind of time-series.

```shell
# want to know top 3 commands at 20170322 on port 6379
% redis-cli -p 6000 ZREVRANGE "6379/20170322" 0 2 WITHSCORES
1) "DEL"
2) "174"
3) "SET"
4) "86"
5) "SADD"
6) "68"
```

#### NOTES

- time-series are hard-coded. (daily, hourly, every minute)
- ttl is hard-coded. (4.weeks, 3.days, 3.hours)
- key format is "{PORT}/{TIME}" in default. (`--out-cmd-key` option overrides it)
  - where `{PORT}` and `{TIME}` are reserved words those will be replaced with runtime values.

see: [src/data/redis_flusher.cr](src/data/redis_flusher.cr)

## Roadmap

- [x] file output
- [x] use pipeline in storing into redis
- [x] store client ip address into redis
- [x] write tests

## Development

- crystal: 0.26.1
- needs `libpcap`
- type `make`

## Contributing

1. Fork it ( https://github.com/maiha/redisniffer.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [maiha](https://github.com/maiha) maiha - creator, maintainer
