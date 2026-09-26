# Registro de decisiones técnicas — Lab 4 DSE

Historial cronológico de decisiones de arquitectura/infra para la conclusión final del reporte.

## 1. Arquitectura base (decisión original, ver ARCHITECTURE.md)
- ALB -> Lambda (direct / cached) sin API Gateway.
- RDS PostgreSQL + ElastiCache Redis (cache-aside) en VPC privada.
- IAM: se reutiliza el rol preexistente `LabRole` de AWS Academy Learner Lab
  (el Learner Lab no permite crear roles/políticas IAM propios).

## 2. Provisioned Concurrency para los Lambdas (decisión revertida en este cambio)
- **Qué se había añadido:** `aws_lambda_alias` (`direct_live` / `cached_live`) +
  `aws_lambda_provisioned_concurrency_config` para ambos Lambdas, con el objetivo
  de eliminar cold starts durante el benchmark con wrk2.
- **Problema encontrado:** al hacer `terraform apply`, el aprovisionamiento de
  `aws_lambda_provisioned_concurrency_config` falló. AWS Academy Learner Lab no
  soporta esta función de forma confiable: el rol `LabRole` y la cuenta del
  Learner Lab tienen límites de concurrencia/recursos de red (Hyperplane ENIs
  para Lambdas en VPC) por debajo de lo que Provisioned Concurrency necesita
  para pasar a estado `READY`, así que Terraform se queda esperando y termina
  en error.
- **Decisión (este cambio):** se elimina `aws_lambda_provisioned_concurrency_config`
  para `direct` y `cached`, y la variable `provisioned_concurrency` en
  `variables.tf`. Se conservan los `aws_lambda_alias` (`*_live`) porque el ALB
  sigue apuntando al alias, no a la función a secas, y eso no depende de
  Provisioned Concurrency.
- **Consecuencia aceptada:** los Lambdas tendrán cold start normal (aceptable
  para un lab académico; no es el foco de la comparación direct vs cached).
- **Estado:** implementado y validado con `terraform validate` (no se corrió
  `terraform apply` completo para no gastar cuota/tiempo del nuevo Learner Lab
  sin necesidad).

## 3. Cuenta de AWS Academy bloqueada por el benchmark
- **Causa:** `benchmark/run.sh` usaba wrk2 con `RATE=2000 req/s`, 8 threads,
  200 conexiones, 15s por prueba (~30,000 requests por endpoint). Contra un
  Learner Lab (cuenta de estudiante con límites bajos de Lambda/RDS/ElastiCache)
  esto disparó throttling/alertas y la cuenta de AWS terminó bloqueada.
- **Decisión:** se baja drásticamente la carga por defecto en `benchmark/run.sh`:
  - `RATE`: 2000 → 20 req/s
  - `THREADS`: 8 → 2
  - `CONNECTIONS`: 200 → 10
  - `DURATION`: se mantiene en 15s
  - Esto da ~300 requests por endpoint por corrida, suficiente para mostrar la
    diferencia direct (RDS) vs cached (Redis) sin volver a saturar la cuenta.
- **Contexto adicional:** por el bloqueo, el estudiante está usando el
  Learner Lab de otra materia para poder entregar esta actividad (cuenta AWS
  distinta a la original, verificada con `aws sts get-caller-identity`).

## 4. Investigación paralela (Sonnet/Gemini)
- Se planteó investigar la causa raíz con dos agentes en paralelo (uno usando
  Sonnet, otro usando Gemini). El entorno disponible solo permite subagentes
  Claude (no hay integración con modelos Gemini en este harness), por lo que
  el usuario decidió que la investigación la hiciera directamente el
  orquestador (Sonnet 5) con su conocimiento de las limitaciones conocidas de
  AWS Academy Learner Lab, sin log de error textual disponible.
