# Workflow: PDF

Este workflow se encarga de generar un archivo PDF a partir de una plantilla de Google Sheets y los datos de un formulario, y luego subir el PDF a Google Drive.

## Pasos del Workflow

1.  **Webhook:** El workflow se inicia al recibir una petición POST en la URL `/formularios`. Se espera que el cuerpo de la petición contenga los datos de un formulario.

2.  **If:** Se comprueba si el tipo de informe es "Inspeccion".

3.  **Switch:** Dependiendo del valor del campo `planilla` en los datos del formulario, se elige una de las siguientes ramas:
    *   **General:** Se edita una plantilla de Google Sheets con los datos del formulario, se exporta como PDF y se sube a Google Drive.
    *   **Femeba:** Se edita una plantilla de Google Sheets con los datos del formulario, se exporta como PDF y se sube a Google Drive.
    *   **Cetec:** Se edita una plantilla de Google Sheets con los datos del formulario, se exporta como PDF y se sube a Google Drive.
    *   **San Martin:** Se edita una plantilla de Google Sheets con los datos del formulario, se exporta como PDF y se sube a Google Drive.
    *   **San Isidro:** Se edita una plantilla de Google Sheets con los datos del formulario, se exporta como PDF y se sube a Google Drive.

4.  **Editar (Google Sheets):** En cada rama, un nodo de `httpRequest` actualiza una plantilla de Google Sheets con los datos del formulario.

5.  **Exportar PDF (Google Sheets):** Otro nodo de `httpRequest` exporta la hoja de cálculo como un archivo PDF.

6.  **Upload file (Google Drive):** Finalmente, el archivo PDF generado se sube a una carpeta específica en Google Drive.

## Cómo crear el workflow

1.  **Crea un nuevo workflow en n8n.**
2.  **Importa el archivo `workflow.json` desde la opción de importar workflow.**
3.  **Asegúrate de que las credenciales para Google Sheets y Google Drive (OAuth2) estén configuradas correctamente.**
4.  **Verifica que los identificadores de las hojas de cálculo y las carpetas de Google Drive en los nodos correspondientes sean los correctos.**
5.  **Ajusta los rangos y los valores en los nodos de `httpRequest` para que coincidan con la estructura de tus plantillas de Google Sheets.**