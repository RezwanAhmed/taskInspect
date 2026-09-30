package com.taskinspect;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

class OpenApiTests {

    @Nested
    @SpringBootTest
    @AutoConfigureMockMvc
    class Development {

        @Autowired
        private MockMvc mockMvc;

        @Test
        void apiDocsDescribeTheApi() throws Exception {
            mockMvc.perform(get("/v3/api-docs"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.info.title").value("TaskInspect API"))
                    .andExpect(jsonPath("$.components.securitySchemes.bearerAuth.scheme").value("bearer"));
        }

        @Test
        void swaggerUiIsAvailable() throws Exception {
            mockMvc.perform(get("/swagger-ui/index.html"))
                    .andExpect(status().isOk());
        }

    }

    @Nested
    @SpringBootTest
    @AutoConfigureMockMvc
    @ActiveProfiles("prod")
    class Production {

        @Autowired
        private MockMvc mockMvc;

        @Test
        void apiDocsAreDisabled() throws Exception {
            mockMvc.perform(get("/v3/api-docs"))
                    .andExpect(status().isNotFound());
        }

    }

}
