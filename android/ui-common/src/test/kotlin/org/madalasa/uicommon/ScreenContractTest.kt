package org.madalasa.uicommon

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ScreenContractTest {
    @Test fun validParentAndChildIds() {
        assertEquals("P-60", ScreenId("P-60").value)
        assertEquals("C-21", ScreenId("C-21").value)
        assertEquals("ST-05", ScreenId("ST-05").value)
    }
    @Test fun invalidIdsRejected() {
        for (id in listOf("P-00", "P-61", "C-22", "ST-06", "../admin")) {
            assertThrows(IllegalArgumentException::class.java) { ScreenId(id) }
        }
    }
    @Test fun actorBoundaryEnforced() {
        assertThrows(IllegalArgumentException::class.java) {
            ScreenDescriptor(ScreenId("C-01"), AppActor.PARENT, "Wrong", "Wrong actor")
        }
    }
}
