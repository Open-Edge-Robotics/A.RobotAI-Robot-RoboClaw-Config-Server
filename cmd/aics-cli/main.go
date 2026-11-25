package main

import (
	"fmt"
	"os"

	"ai-config-server/internal/clicmd"
	"ai-config-server/internal/client"
)

const version = "0.1.0"

func main() {
	root := clicmd.NewRootCommand(version, clicmd.DefaultRuntime())
	if err := root.Execute(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(client.ExitCodeFromError(err))
	}
}
