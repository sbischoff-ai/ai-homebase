{{- define "openhands.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openhands.fullname" -}}
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

{{- define "openhands.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "openhands.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openhands.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "openhands.labels" -}}
helm.sh/chart: {{ include "openhands.chart" . }}
{{ include "openhands.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "openhands.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "openhands.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "openhands.effectiveImagePullSecrets" -}}
{{- $global := .Values.global.imagePullSecrets | default (list) -}}
{{- $local := .Values.imagePullSecrets | default (list) -}}
{{- concat $global $local | uniq | toYaml -}}
{{- end -}}

{{- define "openhands.effectiveStorageClass" -}}
{{- if .Values.workspace.storageClass -}}
{{- .Values.workspace.storageClass -}}
{{- else -}}
{{- .Values.global.storageClass -}}
{{- end -}}
{{- end -}}
