package main

import rego.v1

# Entrada: Dockerfile parseado por Conftest -> lista de instrucciones
# {Cmd, Value, Stage, Flags, ...}

final_stage := max([i.Stage | some i in input])

# La imagen base debe llevar una etiqueta explicita distinta de latest.
deny contains msg if {
	some i in input
	i.Cmd == "from"
	image := i.Value[0]
	not is_previous_stage(image)
	not contains(image, "@sha256:")
	not contains(image, ":")
	msg := sprintf("Imagen base sin etiqueta de version: %s", [image])
}

deny contains msg if {
	some i in input
	i.Cmd == "from"
	endswith(i.Value[0], ":latest")
	msg := sprintf("Imagen base con etiqueta latest: %s", [i.Value[0]])
}

# La etapa final debe declarar un usuario distinto de root.
deny contains msg if {
	not final_stage_has_user
	msg := "La etapa final no declara USER: el contenedor se ejecutaria como root"
}

deny contains msg if {
	some i in input
	i.Cmd == "user"
	i.Stage == final_stage
	lower(split(i.Value[0], ":")[0]) in {"root", "0"}
	msg := "La etapa final se ejecuta como root"
}

# ADD permite URLs remotas y descompresion implicita; usar COPY.
deny contains msg if {
	some i in input
	i.Cmd == "add"
	msg := sprintf("Usar COPY en lugar de ADD: %s", [concat(" ", i.Value)])
}

# No declarar secretos mediante ENV o ARG.
deny contains msg if {
	some i in input
	i.Cmd in {"env", "arg"}
	some v in i.Value
	regex.match(`(?i)(password|passwd|secret|token|api[_-]?key)`, v)
	msg := sprintf("Posible secreto declarado con %s: %s", [upper(i.Cmd), v])
}

warn contains msg if {
	not has_healthcheck
	msg := "El Dockerfile no define HEALTHCHECK"
}

is_previous_stage(image) if {
	some i in input
	i.Cmd == "from"
	count(i.Value) == 3
	lower(i.Value[1]) == "as"
	i.Value[2] == image
}

final_stage_has_user if {
	some i in input
	i.Cmd == "user"
	i.Stage == final_stage
}

has_healthcheck if {
	some i in input
	i.Cmd == "healthcheck"
}
