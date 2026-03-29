{{- define "registry.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "registry.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "registry.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "registry.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "registry.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "registry.selectorLabels" -}}
app.kubernetes.io/name: {{ include "registry.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "registry.storageClass" -}}
{{- if .Values.persistence.storageClass -}}
{{- .Values.persistence.storageClass -}}
{{- else -}}
{{- .Values.global.storageClass -}}
{{- end -}}
{{- end -}}

{{- define "registry.host" -}}
{{- $globalHost := .Values.global.hosts.registry | default "" -}}
{{- $configuredHosts := .Values.ingress.hosts | default (list) -}}
{{- if gt (len $configuredHosts) 0 -}}
{{- default $globalHost (index (index $configuredHosts 0) "host") -}}
{{- else -}}
{{- default $globalHost .Values.ingress.defaultHost -}}
{{- end -}}
{{- end -}}
