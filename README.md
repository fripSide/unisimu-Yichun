
## 学习记录

### TODO  
学习目标：  
- 下载运行部分代码，理解测试开发强大之处
- 寻找perl Test::Base 替代品，如果找不到，用python重写一个
- 继续了解redis, nginx的测试，跟深入的理解需求

当前任务：
- 搞清楚每个文件是啥，选出重点学习目标

### 项目类型

```
CGI  ->  
用Perl CGI模块，写了一个Perl的HTTP Server，能根据静态文件生成网页。

Combinatorics ->
组合数学仿真。

Javascript ->  
JS学习项目。通过Perl扩展JS，定义了一些Perl风格扩展函数，基于这些函数学习了JS语法。
典型的测试驱动项目，虽然JS只有几行，但是测试框架基本写好。


```

### Takeaway
 
1. 测试驱动开发  
理解perl Test::Base强大之处
https://github.com/fripSide/unisimu-Yichun/blob/master/JavaScript/examples.t
```
=== TEST 4: factorial.js w/o args
--- args
factorial.js
--- stderr
usage: factorial.js N
--- stdout
```
能自动对比stdin, stdout
