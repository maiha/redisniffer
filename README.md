# redisniffer.cr

Summarize redis commands via libpcap for [Crystal](http://crystal-lang.org/).

- crystal: 0.21.1

## Usage

```shell
% redisniffer -p '6379'
listening on lo about '(tcp port 6379)' (snaplen: 1500, timeout: 1000)
output: Stdout
[6379, {"ping" => 1}]
[6379, {"get" => 1, "ping" => 1}]
```

## Contributing

1. Fork it ( https://github.com/maiha/redisniffer.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [maiha](https://github.com/maiha) maiha - creator, maintainer
