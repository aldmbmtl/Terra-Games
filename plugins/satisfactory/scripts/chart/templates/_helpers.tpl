{{- /*
  satisfactory.nodeport — deterministic nodePort derived from the instance
  name (stable across ArgoCD syncs / Kuiper re-renders): sha256 hex → sum
  decimal digit-runs → mod 2767 → +30000 (30000..32766, wrap-safe so +1
  never overflows 32767).

  Satisfactory's server is rendered to LISTEN on these derived ports (env
  GAME_PORT / RELIABLE_PORT), so the announced ports are always the
  reachable ones — immune to whether the client derives the reliable
  channel as entered+1 or uses the announced value.
*/ -}}
{{- define "satisfactory.nodeport" -}}
{{- $sum := 0 -}}
{{- range $i, $run := regexFindAll "[0-9]+" (sha256sum .Release.Name) -1 -}}
{{- $sum = add $sum (int $run) -}}
{{- end -}}
{{- add 30000 (mod $sum 2767) -}}
{{- end -}}
