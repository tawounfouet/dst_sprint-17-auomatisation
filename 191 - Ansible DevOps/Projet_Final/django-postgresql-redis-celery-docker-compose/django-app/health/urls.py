from django.urls import path

from . import views

urlpatterns = [
    path("", views.home, name="home"),
    path("health/", views.health, name="health"),
    path("health/database/", views.database_health, name="database-health"),
    path("health/redis/", views.redis_health, name="redis-health"),
    path("health/celery/", views.celery_health, name="celery-health"),
    path("api/info/", views.info, name="api-info"),
]
