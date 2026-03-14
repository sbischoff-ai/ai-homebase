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

{{- define "openhands.persistenceConfig" -}}
{{- $workspace := .Values.workspace | default dict -}}
{{- $persistence := .Values.persistence | default dict -}}

{{- $defaultEnabled := true -}}
{{- $defaultMountPath := "/.openhands" -}}
{{- $defaultAccessModes := list "ReadWriteOnce" -}}
{{- $defaultSize := "20Gi" -}}
{{- $defaultStorageClass := "" -}}
{{- $defaultExistingClaim := "" -}}
{{- $defaultAnnotations := dict -}}

{{- $enabled := $defaultEnabled -}}
{{- if and (hasKey $workspace "enabled") (ne $workspace.enabled nil) -}}
{{- $enabled = $workspace.enabled -}}
{{- end -}}
{{- if and (hasKey $persistence "enabled") (ne $persistence.enabled nil) -}}
{{- $enabled = $persistence.enabled -}}
{{- end -}}
{{- if and (hasKey $workspace "enabled") (ne $workspace.enabled nil) (eq $persistence.enabled $defaultEnabled) -}}
{{- $enabled = $workspace.enabled -}}
{{- end -}}

{{- $mountPath := $defaultMountPath -}}
{{- if and (hasKey $workspace "mountPath") $workspace.mountPath -}}
{{- $mountPath = $workspace.mountPath -}}
{{- end -}}
{{- if and (hasKey $persistence "mountPath") $persistence.mountPath -}}
{{- $mountPath = $persistence.mountPath -}}
{{- end -}}
{{- if and (hasKey $workspace "mountPath") $workspace.mountPath (eq $persistence.mountPath $defaultMountPath) -}}
{{- $mountPath = $workspace.mountPath -}}
{{- end -}}

{{- $existingClaim := $defaultExistingClaim -}}
{{- if hasKey $workspace "existingClaim" -}}
{{- $existingClaim = $workspace.existingClaim -}}
{{- end -}}
{{- if hasKey $persistence "existingClaim" -}}
{{- $existingClaim = $persistence.existingClaim -}}
{{- end -}}
{{- if and (hasKey $workspace "existingClaim") $workspace.existingClaim (eq $persistence.existingClaim $defaultExistingClaim) -}}
{{- $existingClaim = $workspace.existingClaim -}}
{{- end -}}

{{- $accessModes := $defaultAccessModes -}}
{{- if and (hasKey $workspace "accessModes") (gt (len ($workspace.accessModes | default (list))) 0) -}}
{{- $accessModes = $workspace.accessModes -}}
{{- end -}}
{{- if and (hasKey $persistence "accessModes") (gt (len ($persistence.accessModes | default (list))) 0) -}}
{{- $accessModes = $persistence.accessModes -}}
{{- end -}}
{{- if and (hasKey $workspace "accessModes") (gt (len ($workspace.accessModes | default (list))) 0) (eq (toJson $persistence.accessModes) (toJson $defaultAccessModes)) -}}
{{- $accessModes = $workspace.accessModes -}}
{{- end -}}

{{- $size := $defaultSize -}}
{{- if and (hasKey $workspace "size") $workspace.size -}}
{{- $size = $workspace.size -}}
{{- end -}}
{{- if and (hasKey $persistence "size") $persistence.size -}}
{{- $size = $persistence.size -}}
{{- end -}}
{{- if and (hasKey $workspace "size") $workspace.size (eq $persistence.size $defaultSize) -}}
{{- $size = $workspace.size -}}
{{- end -}}

{{- $storageClass := $defaultStorageClass -}}
{{- if hasKey $workspace "storageClass" -}}
{{- $storageClass = $workspace.storageClass -}}
{{- end -}}
{{- if hasKey $persistence "storageClass" -}}
{{- $storageClass = $persistence.storageClass -}}
{{- end -}}
{{- if and (hasKey $workspace "storageClass") $workspace.storageClass (eq $persistence.storageClass $defaultStorageClass) -}}
{{- $storageClass = $workspace.storageClass -}}
{{- end -}}

{{- $annotations := $defaultAnnotations -}}
{{- if hasKey $workspace "annotations" -}}
{{- $annotations = $workspace.annotations -}}
{{- end -}}
{{- if hasKey $persistence "annotations" -}}
{{- $annotations = $persistence.annotations -}}
{{- end -}}
{{- if and (hasKey $workspace "annotations") (gt (len ($workspace.annotations | default (dict))) 0) (eq (len ($persistence.annotations | default (dict))) 0) -}}
{{- $annotations = $workspace.annotations -}}
{{- end -}}

enabled: {{ $enabled }}
mountPath: {{ $mountPath | quote }}
existingClaim: {{ $existingClaim | quote }}
accessModes:
{{- toYaml $accessModes | nindent 2 }}
size: {{ $size | quote }}
storageClass: {{ $storageClass | quote }}
annotations:
{{- toYaml $annotations | nindent 2 }}
{{- end -}}

{{- define "openhands.effectiveStorageClass" -}}
{{- $config := include "openhands.persistenceConfig" . | fromYaml -}}
{{- if $config.storageClass -}}
{{- $config.storageClass -}}
{{- else -}}
{{- .Values.global.storageClass -}}
{{- end -}}
{{- end -}}
