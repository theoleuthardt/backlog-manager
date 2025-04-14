package routes

import (
	"github.com/go-chi/chi/v5"
	"github.com/theoleuthardt/backlog-manager/backend/internal/api/handlers"
)

func SetupRoutes(r *chi.Mux, h *handlers.Handlers) {
	r.Route("/users", func(r chi.Router) {
		r.Post("/create", h.UserHandler.CreateUser)
	})
}
