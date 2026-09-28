package com.example.demo;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

class HelloServiceTest {

	private final HelloService service = new HelloService();

	@Test
	void shouldReturnExpectedMessage() {
		assertEquals("Hello from Jenkins CI/CD!", service.message());
	}
}
