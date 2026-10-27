package dev.theocloud.monitor;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("prod")
@Import(TestcontainersConfiguration.class)
class ProdProfileTests {

    @Autowired
    private MockMvcTester mvc;

    @Test
    void healthShowsNoDetails() {
        assertThat(mvc.get().uri("/actuator/health"))
                .hasStatusOk()
                .bodyJson()
                .doesNotHavePath("$.components")
                .extractingPath("$.status")
                .isEqualTo("UP");
    }
}
