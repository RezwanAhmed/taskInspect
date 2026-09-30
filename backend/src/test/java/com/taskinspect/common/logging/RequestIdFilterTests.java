package com.taskinspect.common.logging;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class RequestIdFilterTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void generatesRequestIdWhenNoneIsSent() throws Exception {
        MvcResult result = mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andReturn();

        String requestId = result.getResponse().getHeader(RequestIdFilter.HEADER);
        assertThat(UUID.fromString(requestId)).isNotNull();
    }

    @Test
    void reusesValidRequestIdFromClient() throws Exception {
        mockMvc.perform(get("/actuator/health").header(RequestIdFilter.HEADER, "app-3f2a9c1e"))
                .andExpect(header().string(RequestIdFilter.HEADER, "app-3f2a9c1e"));
    }

    @Test
    void replacesInvalidRequestIdFromClient() throws Exception {
        MvcResult result = mockMvc.perform(get("/actuator/health")
                        .header(RequestIdFilter.HEADER, "bad id\nwith newline"))
                .andReturn();

        String requestId = result.getResponse().getHeader(RequestIdFilter.HEADER);
        assertThat(UUID.fromString(requestId)).isNotNull();
    }

    @Test
    void errorResponseContainsTheSameRequestId() throws Exception {
        mockMvc.perform(get("/api/does-not-exist").header(RequestIdFilter.HEADER, "req-42"))
                .andExpect(status().isNotFound())
                .andExpect(header().string(RequestIdFilter.HEADER, "req-42"))
                .andExpect(jsonPath("$.requestId").value("req-42"));
    }

    @Test
    void requestIdIsRemovedFromLoggingContextAfterTheRequest() throws Exception {
        mockMvc.perform(get("/actuator/health").header(RequestIdFilter.HEADER, "req-43"));

        assertThat(MDC.get(RequestIdFilter.MDC_KEY)).isNull();
    }

}
