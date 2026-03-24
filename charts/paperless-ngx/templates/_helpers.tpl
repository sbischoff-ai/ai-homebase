{{- define "paperless-ngx.name" -}}{{- default .Chart.Name .Values.nameOverride | kebabcase | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- define "paperless-ngx.fullname" -}}{{- if .Values.fullnameOverride -}}{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name (include "paperless-ngx.name" .) | trunc 63 | trimSuffix "-" -}}{{- end -}}{{- end -}}
{{- define "paperless-ngx.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "paperless-ngx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
{{- define "paperless-ngx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "paperless-ngx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "paperless-ngx.storageClass" -}}
{{- $persistence := index . 0 -}}
{{- $root := index . 1 -}}
{{- if $persistence.storageClass -}}{{ $persistence.storageClass }}{{- else -}}{{ $root.Values.global.storageClass }}{{- end -}}
{{- end -}}
{{- define "paperless-ngx.pvcName" -}}
{{- $root := index . 0 -}}
{{- $suffix := index . 1 -}}
{{- printf "%s-%s" (include "paperless-ngx.fullname" $root) $suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "paperless-ngx.ingressHost" -}}
{{- $globalHost := coalesce .Values.global.hosts.paperless .Values.global.hosts.paperlessNgx -}}
{{- $hosts := .Values.ingress.hosts | default (list) -}}
{{- $firstHost := "" -}}
{{- if and (kindIs "slice" $hosts) (gt (len $hosts) 0) -}}
  {{- $firstHost = default "" (get (index $hosts 0) "host") -}}
{{- end -}}
{{- coalesce $firstHost $globalHost -}}
{{- end -}}
{{- define "paperless-ngx.externalUrl" -}}
{{- $host := include "paperless-ngx.ingressHost" . -}}
{{- if .Values.appConfig.url -}}
{{- .Values.appConfig.url -}}
{{- else if $host -}}
{{- printf "http://%s" $host -}}
{{- end -}}
{{- end -}}
{{- define "paperless-ngx.allowedHosts" -}}
{{- if .Values.appConfig.allowedHosts -}}
{{- .Values.appConfig.allowedHosts -}}
{{- else -}}
{{- include "paperless-ngx.ingressHost" . -}}
{{- end -}}
{{- end -}}
{{- define "paperless-ngx.csrfTrustedOrigins" -}}
{{- if .Values.appConfig.csrfTrustedOrigins -}}
{{- .Values.appConfig.csrfTrustedOrigins -}}
{{- else -}}
{{- include "paperless-ngx.externalUrl" . -}}
{{- end -}}
{{- end -}}
