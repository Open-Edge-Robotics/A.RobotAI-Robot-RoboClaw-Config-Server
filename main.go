package main

import (
	"fmt"
	"os"

	"ai-config-server/cmd"
	"ai-config-server/internal/clicmd"
	"ai-config-server/internal/client"
	"github.com/wkqco33/wcli"
	"github.com/wkqco33/wcli/logging"
)

const version = "0.1.0"

func main() {
	logger := logging.NewDefaultLogger(os.Stderr, logging.LevelInfo, true)
	logging.SetLogger(logger)

	root := &wcli.Command{
		Use:           "aics",
		Aliases:       []string{"ai-config-server"},
		Short:         "ai-config-server 서버 및 원격 관리 CLI",
		Version:       version,
		SilenceErrors: true,
	}

	root.AddCommand(
		cmd.ServeCmd(),
		cmd.ContractCmd(),
		cmd.SecretScanCmd(),
		cmd.VersionCmd(version),
		wcli.NewCompletionCommand(root),
	)
	clicmd.RegisterCommands(root, clicmd.DefaultRuntime())

	if err := root.Execute(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(client.ExitCodeFromError(err))
	}
}
