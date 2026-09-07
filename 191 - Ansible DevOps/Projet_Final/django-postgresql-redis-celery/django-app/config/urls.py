from django.urls import include, path

urlpatterns = [
    path("", include("health.urls")),
    path("", include("tasks_demo.urls")),
]
