# Flujo editorial y revisión

```text
Editorial package
  → Creative Scriptwriter
  → script pending review
  → Production Director
  → production pending review
  → Discord notification
  → aprobación humana
  → Fish Audio → audio review → Remotion → video review → publicación
```

- **Creative** escribe únicamente la narración factual y el Markdown legible.
- **Production** recibe una narración aprobada y crea dirección Fish, avatar,
  visuales, captions y Remotion; no puede cambiar el texto.
- Cada etapa conserva su respuesta y estado en PostgreSQL.
- Discord notificará cada revisión y registrará aprobación, rechazo o cambios.
- Ningún audio, vídeo o publicación se activa sin una decisión humana explícita.
