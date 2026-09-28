package com.example.demo;

import org.springframework.stereotype.Service;

@Service
public class HelloService {

	public String message() {
		return "Hello from Jenkins CI/CD!";
	}
}
