#!/usr/bin/env bash

main () {

	FILE="$1"
	install -Dv /dev/null "./src/Hooks/$FILE.js"
	read -r -d '' content << EOM
import React from "react";

export function usefuncName(){
	return(
		<h1>Component Created Successfully :)</h1>
	)
}

EOM

echo "${content//funcName/$FILE}" >> "./src/Hooks/$FILE.js"
}

main "$@"
