package com.taskinspect.common.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI description of the REST API, shown in Swagger UI at
 * {@code /swagger-ui.html}. Controllers are picked up automatically.
 */
@Configuration
public class OpenApiConfig {

    public static final String BEARER_AUTH = "bearerAuth";

    @Bean
    OpenAPI taskInspectOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("TaskInspect API")
                        .version("v1")
                        .description("REST API for creating, assigning, executing and reviewing "
                                + "tasks and inspections."))
                .components(new Components()
                        .addSecuritySchemes(BEARER_AUTH, new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                                .description("Access token from POST /api/auth/login")));
    }

}
