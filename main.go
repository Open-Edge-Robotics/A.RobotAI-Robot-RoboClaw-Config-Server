package main

import (
	"fmt"
	"os"

	"ai-config-server/cmd"
	"github.com/wkqco33/wcli"
	"github.com/wkqco33/wcli/logging"
)

const version = "0.1.0"

func main() {
	logger := logging.NewDefaultLogger(os.Stderr, logging.LevelInfo, true)
	logging.SetLogger(logger)

	root := &wcli.Command{
		Use:     "aics",
		Aliases: []string{"ai-config-server"},
		Short:   "ai-config-server 서버",
		Version: version,
		PersistentPreRun: func(ctx *wcli.Context) error {
			return cmd.InitConfig()
		},
	}

	root.AddCommand(
		cmd.ServeCmd(),
		cmd.ContractCmd(),
		cmd.SecretScanCmd(),
		cmd.VersionCmd(version),
		wcli.NewCompletionCommand(root),
	)

	if err := root.Execute(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
