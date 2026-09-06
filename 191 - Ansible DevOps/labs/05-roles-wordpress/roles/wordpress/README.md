# Role `wordpress`

Rôle pédagogique issu du chapitre DataScientest « Les Roles ».

Il installe PHP, Nginx, WordPress et le service MySQL sur l’hôte du groupe `production` dans le lab Multipass. Les variables sensibles ne doivent pas être versionnées en clair ; leur traitement est finalisé au chapitre Vault.

## Variables principales

- `wp_version`
- `wp_install_dir`
- `wp_webserver`
- `wp_sitename`
- `wp_db_name`
- `wp_db_user`
- `wp_db_host`
- `wp_db_charset`
- `wp_db_password` (à fournir hors du rôle)

## Appel

```yaml
roles:
  - wordpress
```
