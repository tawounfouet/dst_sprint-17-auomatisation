from rest_framework import serializers


class StrictNumberField(serializers.Field):
    default_error_messages = {
        "invalid": "A JSON number is required.",
    }

    def to_internal_value(self, data):
        if isinstance(data, bool) or not isinstance(data, (int, float)):
            self.fail("invalid")
        return data

    def to_representation(self, value):
        return value


class StrictBoundedStringField(serializers.Field):
    default_error_messages = {
        "invalid": "A non-empty string up to 1024 characters is required.",
    }

    def to_internal_value(self, data):
        if not isinstance(data, str) or not data or len(data) > 1024:
            self.fail("invalid")
        return data

    def to_representation(self, value):
        return value


class AddTaskSerializer(serializers.Serializer):
    x = StrictNumberField()
    y = StrictNumberField()


class UppercaseTaskSerializer(serializers.Serializer):
    value = StrictBoundedStringField()


class TaskAcceptedSerializer(serializers.Serializer):
    task_id = serializers.CharField()
    status = serializers.CharField()


class TaskStatusSerializer(serializers.Serializer):
    task_id = serializers.CharField()
    status = serializers.CharField()
    result = serializers.JSONField(required=False)
    error = serializers.CharField(required=False)


class MediaUploadSerializer(serializers.Serializer):
    file = serializers.FileField()
