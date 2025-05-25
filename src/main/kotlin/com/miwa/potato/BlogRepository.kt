package com.miwa.potato

import com.miwa.potato.generated.jooq.Tables.USERS
import com.miwa.potato.generated.jooq.tables.records.UsersRecord
import org.jooq.DSLContext
import org.springframework.stereotype.Repository

@Repository
class BlogRepository(
    private val context: DSLContext
) {
    fun findAll(): List<User> {
        return context.selectFrom(USERS)
            .toList()
            .map { it.toDomainModel() }
    }

    private fun UsersRecord.toDomainModel(): User {
        return User(
            id = this.id.toString(),
            name = this.name
        )
    }
}