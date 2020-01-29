global
	 log 127.0.0.1 local0 notice
	 maxconn 2000
	 user haproxy
	 group haproxy

defaults
	 log     global
	 mode    http
	 option  httplog
	 option  dontlognull
	 #retries 3
	 #option redispatch
	 timeout connect  5000
	 timeout client  10000


frontend http-in
        bind *:80

        # Define UI hosts{{ range services }}{{ range service .Name }}{{if in .Tags "ui"}}
        acl host_{{.Name}} hdr(host) -i {{ .Name }}.pennsignals.uphs.upenn.edu{{end}}{{end}}{{end}}

        # Monitoring hosts{{ range services }}{{if in .Tags "monitoring"}}{{range $index, $service := service .Name }}
        acl host_{{.Name}}_{{$index | add 1}} hdr(host) -i {{ .Name }}-minion-{{$index | add 1}}.pennsignals.uphs.upenn.edu{{end}}{{end}}{{end}}

        # Figure out which UI backend to use{{ range services }}{{ range service .Name }}{{if in .Tags "ui"}}
        use_backend {{ .Name }}_cluster if host_{{ .Name }}{{end}}{{end}}{{end}}

        # Figure out which Monitoring backend to use{{ range services }}{{if in .Tags "monitoring"}}{{range $index, $service := service .Name }}
        use_backend {{ .Name }}_{{$index | add 1}}_cluster if host_{{ .Name }}_{{$index | add 1}}{{end}}{{end}}{{end}}

{{ range services }}{{ if in .Tags "ui" }}
backend {{ .Name }}_cluster
        balance roundrobin
        cookie SERVERID insert indirect nocache
        {{ range service .Name }}server {{ .Node }} {{ .Address }}:{{.Port}} check cookie 170.166.25.206-{{ .Node}}
        {{end}}{{end}}{{end}}

{{ range services }}{{if in .Tags "monitoring"}}
{{range $index, $service := service .Name }}
backend {{.Name}}_{{$index | add 1}}_cluster
        balance roundrobin
        cookie SERVERID insert indirect nocache
        server {{ .Node }} {{$service.Address}}:{{$service.Port}} check cookie 170.166.25.206-{{ .Node}}
        {{end}}{{end}}{{end}}
	
listen admin
        bind 0.0.0.0:9000
        mode http
        stats enable
        stats uri /admin
        stats refresh 5
        stats realm HAProxy\ Statistics
        stats auth pennsignals:datascience