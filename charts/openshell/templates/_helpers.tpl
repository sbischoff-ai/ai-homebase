{{- define "openshell.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openshell.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "openshell.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openshell.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openshell.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "openshell.labels" -}}
helm.sh/chart: {{ include "openshell.chart" . }}
{{ include "openshell.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "openshell.serviceName" -}}
{{- default "openshell" .Values.service.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openshell.effectiveImagePullSecrets" -}}
{{- $global := .Values.global.imagePullSecrets | default (list) -}}
{{- $local := .Values.imagePullSecrets | default (list) -}}
{{- concat $global $local | uniq | toYaml -}}
{{- end -}}
