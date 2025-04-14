package handlers

import "github.com/theoleuthardt/backlog-manager/backend/internal/db/repositories"

type Handlers struct {
	UserHandler *UserHandler
}

func NewHandlers(ur *repositories.UserRepository) *Handlers {
	return &Handlers{
		UserHandler: NewUserHandler(ur),
	}
}
