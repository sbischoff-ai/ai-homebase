{{- define "memgraph-lab.name" -}}
{{- default (.Chart.Name | kebabcase) .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "memgraph-lab.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "memgraph-lab.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "memgraph-lab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "memgraph-lab.selectorLabels" -}}
app.kubernetes.io/name: {{ include "memgraph-lab.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "memgraph-lab.labels" -}}
helm.sh/chart: {{ include "memgraph-lab.chart" . | kebabcase }}
{{ include "memgraph-lab.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
