{{- define "vaultwarden.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vaultwarden.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "vaultwarden.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "vaultwarden.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "vaultwarden.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vaultwarden.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "vaultwarden.storageClass" -}}
{{- if .Values.persistence.storageClass -}}
{{- .Values.persistence.storageClass -}}
{{- else -}}
{{- .Values.global.storageClass -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.host" -}}
{{- $globalHost := .Values.global.hosts.vaultwarden | default "" -}}
{{- $hosts := .Values.ingress.hosts | default (list) -}}
{{- if gt (len $hosts) 0 -}}
{{- default $globalHost (index (index $hosts 0) "host") -}}
{{- else -}}
{{- $globalHost -}}
{{- end -}}
{{- end -}}

{{- define "vaultwarden.domain" -}}
{{- $configuredDomain := .Values.appConfig.domain | default "" -}}
{{- if $configuredDomain -}}
{{- $configuredDomain -}}
{{- else -}}
{{- $host := include "vaultwarden.host" . -}}
{{- if $host -}}
{{- printf "https://%s" $host -}}
{{- end -}}
{{- end -}}
{{- end -}}
