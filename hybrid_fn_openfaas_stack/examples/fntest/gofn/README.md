This is basically the simple "Hello World" example from the Fn tutorial https://github.com/fnproject/tutorials/blob/master/Introduction/README.md but it serves as a good test that the server and other infrastructure such as the container registry are all available and behaving.

It is necessary to ensure that the Fn context points to the required FN\_API\_URL and REGISTRY e.g.
```
fn list contexts
CURRENT	NAME	PROVIDER	API URL			REGISTRY
*	default	default		http://10.192.0.2:30080	docker-mint.local:5000
```
If this is not the case then update with the following commands:
```
fn use context default
```
```
fn update context registry docker-mint.local:5000
```
```
fn update context api-url http://10.192.0.2:30080
```
To create and run this function it's basically a case of following the tutorial. This directory was created by running:
```
fn init --runtime go --trigger http gofn
```
which created all of the boilerplate code and config in this directory.

To create an app and deploy the function (from this directory):
```
fn create app goapp
fn --verbose deploy --app goapp
```
Note that only the app name is specified to the CLI and the function name (gofn) is specified in the func.yaml (and will eventually be used as the container name).

The function may be invoke via:
```
fn invoke goapp gofn
```
or
```
echo -n '{"name":"Bob"}' | fn invoke goapp gofn --content-type application/json
```

or via Curl:
```
curl -H "Content-Type: application/json" http://10.192.0.2:30090/t/goapp/gofn
```
or
```
curl -H "Content-Type: application/json" -d '{"name":"Bob"}' http://10.192.0.2:30090/t/goapp/gofn
```
**N.B.** it is important to use the URL that is illustrated by the output of running `fn deploy` e.g. "Trigger Endpoint: http://10.192.0.2:30090/t/goapp/gofn" because the tutorial at https://github.com/fnproject/tutorials/blob/master/Introduction/README.md refers to "gofn-trigger" whereas the generated trigger is now simply "gofn" also the host and port info need to be set to the correct values. Note too that when running in a cluster environment the port used is that of the fn-runner (in this case 30090) and not that of the API server (30080). These little things can often catch you out.
