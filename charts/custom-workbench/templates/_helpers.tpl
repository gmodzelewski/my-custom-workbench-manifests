{{/*
Expand the name of the chart.
*/}}
{{- define "custom-workbench.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "custom-workbench.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "custom-workbench.labels" -}}
helm.sh/chart: {{ include "custom-workbench.chart" . }}
{{ include "custom-workbench.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "custom-workbench.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "custom-workbench.selectorLabels" -}}
app.kubernetes.io/name: {{ include "custom-workbench.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "custom-workbench.rhoaiNamespace" -}}
{{- .Values.rhoai.namespace }}
{{- end }}

{{- define "custom-workbench.workbenchNamespace" -}}
{{- .Values.workbench.namespace }}
{{- end }}

{{- define "custom-workbench.imageTag" -}}
{{- .Values.global.imageTag }}
{{- end }}

{{- define "custom-workbench.quayWorkbenchImage" -}}
{{- printf "quay.io/%s/%s:%s" .Values.global.quayOrg .Values.rhoai.imageName (include "custom-workbench.imageTag" .) }}
{{- end }}

{{- define "custom-workbench.quayRuntimeImage" -}}
{{- printf "quay.io/%s/%s:%s" .Values.global.quayOrg .Values.rhoai.runtimeImageName (include "custom-workbench.imageTag" .) }}
{{- end }}

{{- define "custom-workbench.internalWorkbenchImage" -}}
{{- printf "image-registry.openshift-image-registry.svc:5000/%s/%s:%s" .Values.rhoai.namespace .Values.rhoai.imageName (include "custom-workbench.imageTag" .) }}
{{- end }}

{{- define "custom-workbench.sourceGitUrl" -}}
{{- .Values.global.sourceGitUrl }}
{{- end }}

{{- define "custom-workbench.manifestsGitUrl" -}}
{{- .Values.global.manifestsGitUrl }}
{{- end }}

{{- define "custom-workbench.cloneRepoUrlFor" -}}
{{- $root := index . "root" -}}
{{- $dir := index . "dir" -}}
{{- $url := index . "url" -}}
{{- if $url -}}
{{- $url -}}
{{- else if eq $dir "my-custom-workbench-manifests" -}}
{{- include "custom-workbench.manifestsGitUrl" $root -}}
{{- else -}}
{{- include "custom-workbench.sourceGitUrl" $root -}}
{{- end -}}
{{- end }}

{{- define "custom-workbench.secret.quay" -}}
{{- .Values.secrets.quay.name }}
{{- end }}

{{- define "custom-workbench.secret.githubPat" -}}
{{- .Values.secrets.github.patName }}
{{- end }}

{{- define "custom-workbench.secret.webhook" -}}
{{- .Values.secrets.github.webhookSecretName }}
{{- end }}

{{- define "custom-workbench.workbenchGitUsername" -}}
{{- if .Values.workbench.gitCredentials.username }}
{{- .Values.workbench.gitCredentials.username }}
{{- else }}
{{- .Values.secrets.github.patUsername }}
{{- end }}
{{- end }}

{{- define "custom-workbench.workbenchGitSecret" -}}
{{- .Values.workbench.gitCredentials.secretName }}
{{- end }}

{{- define "custom-workbench.workbenchGitSecretEnabled" -}}
{{- if and .Values.workbench.gitCredentials.enabled (or .Values.secrets.create .Values.workbench.gitCredentials.createSecret .Values.workbench.gitCredentials.useExistingSecret) -}}true{{- end -}}
{{- end }}

{{- define "custom-workbench.workbenchGitSecretCreate" -}}
{{- if and .Values.workbench.gitCredentials.enabled (or .Values.secrets.create .Values.workbench.gitCredentials.createSecret) -}}true{{- end -}}
{{- end }}

{{- define "custom-workbench.imageSelection" -}}
{{- printf "%s:%s" .Values.rhoai.imageName (include "custom-workbench.imageTag" .) }}
{{- end }}
