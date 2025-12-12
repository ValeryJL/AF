# Workflow: Cámaras Transformadoras

Este workflow se encarga de recibir datos de mediciones de transformadores, procesarlos y almacenarlos en una base de datos NocoDB, evitando la duplicación de registros.

## Pasos del Workflow

1.  **Webhook:** El workflow se inicia al recibir una petición POST en la URL `/agregar_trafos`. Se espera que el cuerpo de la petición contenga un array de mediciones.

2.  **Code:** Un nodo de código procesa cada una de las mediciones recibidas. Extrae la fecha y la hora del campo `fecha`, y las formatea en campos separados `fecha_solo` y `hora_solo`.

3.  **Loop Over Items:** Se itera sobre cada una de las mediciones procesadas.

4.  **Get many rows:** Por cada medición, se consulta la base de datos NocoDB para verificar si ya existe un registro con el mismo transformador, fecha y hora.

5.  **If:** Se evalúa el resultado de la consulta anterior. Si no se encontraron registros, se procede a crear uno nuevo.

6.  **Create a row:** Se crea un nuevo registro en la tabla `mix04t5g5fchblz` de NocoDB con los datos de la medición.

7.  **Loop Over Items (End):** Finaliza la iteración.

## Cómo crear el workflow

1.  **Crea un nuevo workflow en n8n.**
2.  **Importa el archivo `workflow.json` desde la opción de importar workflow.**
3.  **Asegúrate de que las credenciales para NocoDB estén configuradas correctamente.**
4.  **Verifica que los identificadores de proyecto y tabla en los nodos de NocoDB (`Create a row` y `Get many rows`) coincidan con tu configuración.**