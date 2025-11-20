{{/*
Expand the name of the chart.
*/}}
{{- define "eventos-backend.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create a full name using the release name.
*/}}
{{- define "eventos-backend.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "eventos-backend.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}
