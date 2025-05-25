package com.miwa.potato

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class PotatoApplication

fun main(args: Array<String>) {
    runApplication<PotatoApplication>(*args)
}
