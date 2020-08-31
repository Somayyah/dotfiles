#!/usr/bin/env bash

main () {

	FILE="$1"
	install -Dv /dev/null "./src/components/$FILE.js"
	read -r -d '' content << EOM
import React from "react";

function funcName(){
	return(
		<h1>Component Created Successfully :)</h1>
	)
}

export default funcName;
EOM

echo "${content//funcName/$FILE}" >> "./src/components/$FILE.js"
}

main "$@"
