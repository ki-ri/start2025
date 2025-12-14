package com.miwa.potato.repository

import com.miwa.potato.domain.repository.UserRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest

@SpringBootTest
internal class UserRepositoryImplTest {
    @Autowired
    private lateinit var userRepository: UserRepository

    @Test
    fun FindAllが成功() {
        userRepository.findAll()
    }
}