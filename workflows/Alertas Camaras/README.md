# Workflow: Alertas Cámaras

Este workflow se ejecuta periódicamente para monitorear el estado de los transformadores, detectar fallos y enviar alertas a través de Telegram.

## Pasos del Workflow

1.  **Schedule Trigger:** El workflow se ejecuta cada minuto.

2.  **Execute a SQL query:** Se ejecuta una consulta en la base de datos PostgreSQL para obtener las últimas mediciones de cada transformador.

3.  **Code:** Un nodo de código procesa los resultados de la consulta.
    *   Mantiene un estado de los transformadores para detectar cambios.
    *   Verifica si los datos son recientes o si hay un fallo en el suministro de datos.
    *   Detecta fallos de equipo por tensión o corriente cero.
    *   Agrupa las alertas para enviar un único mensaje consolidado.
    *   Genera un mensaje de alerta o restauración según los cambios de estado detectados.

4.  **Send a text message:** Si se generó un mensaje de alerta o restauración, se envía a un chat de Telegram específico.

## Cómo crear el workflow

1.  **Crea un nuevo workflow en n8n.**
2.  **Importa el archivo `workflow.json` desde la opción de importar workflow.**
3.  **Asegúrate de que las credenciales para PostgreSQL y Telegram estén configuradas correctamente.**
4.  **Verifica que el `chatId` en el nodo de Telegram (`Send a text message`) sea el correcto.**
5.  **Ajusta los umbrales y la lógica en el nodo de `Code` según tus necesidades.**