
# Workflows de n8n

En esta carpeta se encuentran los archivos JSON y la documentación de los workflows de n8n utilizados en este proyecto.

Cada subcarpeta corresponde a un workflow y contiene:

*   `workflow.json`: El archivo JSON que se puede importar en n8n para crear el workflow.
*   `README.md`: Una explicación detallada del funcionamiento del workflow, incluyendo los pasos que sigue y las credenciales y configuraciones necesarias.

## Workflows disponibles

*   **Alertas Camaras:** Monitorea el estado de los transformadores y envía alertas por Telegram.
*   **Camaras Transformadoras:** Recibe y almacena mediciones de transformadores en NocoDB.
*   **PDF:** Genera PDFs a partir de plantillas de Google Sheets y los sube a Google Drive.
