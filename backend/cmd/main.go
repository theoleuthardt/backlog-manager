package main

import (
	"github.com/joho/godotenv"
	"github.com/theoleuthardt/backlog-manager/backend/internal/api"
	"github.com/theoleuthardt/backlog-manager/backend/internal/config"
	"github.com/theoleuthardt/backlog-manager/backend/internal/db"
	"github.com/theoleuthardt/backlog-manager/backend/internal/logger"
	"go.uber.org/zap"
)

func main() {
	logger.InitLogger()
	defer logger.CloseLogger()

	err := godotenv.Load()
	if err != nil {
		logger.Logger.Fatal("Error loading .env file", zap.Error(err))
	}

	cfg := config.NewConfig()

	err = cfg.ParseFlags()
	if err != nil {
		logger.Logger.Fatal("Failed to parse command-line flags", zap.Error(err))
	}

	db, err := db.Connect(cfg)
	if err != nil {
		logger.Logger.Fatal("Failed to connect to the database", zap.Error(err))
		panic(err)
	}
	defer db.Close()

	hr := cfg.InitializeHandlers(cfg.InitializeRepositories(db))
	srv := api.NewAPI(logger.Logger, cfg, hr)

	err = srv.Run()
	if err != nil {
		logger.Logger.Fatal("Failed to start the server", zap.Error(err))
	}
}
