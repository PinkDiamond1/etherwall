/*
    This file is part of etherwall.
    etherwall is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    etherwall is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with etherwall. If not, see <http://www.gnu.org/licenses/>.
*/
/** @file ContractDetails.qml
 * @author Ales Katona <almindor@gmail.com>
 * @date 2016
 *
 * FirstTime dialog
 */

import QtQuick 2.0
import QtQuick.Dialogs 1.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1

Dialog {
    id: contractDetails
    title: qsTr("Contract Details")
    standardButtons: StandardButton.Close
    modality: Qt.WindowModal
    visible: false
    width: 7 * dpi
    height: 5 * dpi

    function display( index ) {
        if ( index < 0 ) {
            nameField.text = ""
            addressField.text = ""
            abiField.text = ""

            open()
            return
        }

        nameField.text = contractModel.getName(index)
        addressField.text = contractModel.getAddress(index)
        abiField.text = contractModel.getABI(index)

        open()
    }

    BusyIndicator {
        anchors.centerIn: parent
        z: 10
        running: ipc.starting || ipc.busy || ipc.syncing || contractModel.busy
    }

    Column {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 0.1 * dpi
        spacing: 0.2 * dpi

        Row {
            Label {
                width: 1 * dpi
                text: qsTr("Address: ")
            }

            TextField {
                id: addressField
                width: mainColumn.width - 1 * dpi
                validator: RegExpValidator {
                    regExp: /0x[a-f,A-Z,0-9]{40}/
                }

                maximumLength: 42

                onTextChanged: {
                    var full = false
                    // if we have a full address on ETH main chain, we can query etherscan.io for the ABI
                    if ( text.length == 42 && !ipc.testnet ) {
                        contractModel.requestAbi(text)
                        full = true
                    }
                    saveButton.refresh(full)
                }
            }
        }

        Row {
            Label {
                text: qsTr("Interface: ")
                width: 1 * dpi
            }

            TextArea {
                id: abiField
                width: mainColumn.width - 1 * dpi
                height: 1.0 * dpi
                wrapMode: TextEdit.WrapAnywhere

                onTextChanged: saveButton.refresh()

                Connections {
                    target: contractModel

                    onAbiResult: {
                        abiField.text = abi
                        saveButton.refresh(true)
                    }
                }
            }
        }

        Row {
            Label {
                width: 1 * dpi
                text: qsTr("Name: ")
            }

            TextField {
                id: nameField
                width: mainColumn.width - 1 * dpi

                maximumLength: 255

                onTextChanged: saveButton.refresh()
            }

            Connections {
                target: contractModel

                onCallNameDone: nameField.text = name
            }
        }

        Row {
            Label {
                text: qsTr("Status: ")
                width: 1 * dpi
            }

            TextField {
                id: errorField
                width: mainColumn.width - 1 * dpi
                readOnly: true
                property bool ready: false

                style: TextFieldStyle {
                    textColor: "black"
                    background: Rectangle {
                        radius: 2
                        border.color: errorField.ready ? "green" : "red"
                        border.width: 1
                    }
                }
            }

        }

        Button {
            id: saveButton
            width: parent.width
            height: 1.3 * dpi
            text: "Save"

            Image {
                id: saveIcon
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: parent.height * 0.15
                width: height
                source: "/images/warning"
            }

            style: ButtonStyle {
              label: Text {
                renderType: Text.NativeRendering
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: saveButton.height / 2.0
                text: control.text
              }
            }

            function check(full) {
                var result = {
                    error: null,
                    name: null,
                    address: null,
                    abi: null
                }

                result.address = addressField.text || ""
                if ( !result.address.match(/0x[a-f,A-Z,0-9]{40}/) ) {
                    result.error = qsTr("Contract address invalid")
                    return result
                }

                if ( !helpers.checkAddress(result.address) ) {
                    result.error = qsTr("Contract address invalid checksum")
                    return result
                }

                var trimmed = (abiField.text || '').trim()
                if ( !trimmed || !trimmed.length ) {
                    result.error = 'JSON interface not specified'
                    return result
                }

                try {
                    var parsed = JSON.parse(abiField.text)
                    if ( !parsed || !parsed.length ) {
                        result.error = "API not an array"
                        return result
                    }

                    result.abi = abiField.text
                } catch ( err ) {
                    result.error = "Interface parse error: " + err
                    return result
                }

                result.name = nameField.text.trim() || ""
                if ( result.name.length === 0 ) {
                    // attempt to get name from contract itself if abi supports
                    if ( full ) {
                        contractModel.callName(result.address, result.abi)
                    }
                    result.error = qsTr("Invalid contract name")
                    return result
                }

                return result;
            }

            function refresh(full) {
                var result = check(full)
                if ( result.error !== null ) {
                    errorField.text = result.error
                    tooltip = result.error
                    saveIcon.source = "/images/warning"
                    errorField.ready = false
                    return result
                } else {
                    errorField.text = qsTr("Ready")
                    errorField.ready = true
                }

                saveIcon.source = "/images/ok"
                return result
            }

            onClicked: {
                var result = refresh()
                if ( result.error !== null ) {
                    errorDialog.text = result.error
                    errorDialog.open()
                    return
                }

                contractModel.addContract(result.name, result.address, result.abi)
                contractDetails.close()
            }
        }
    }
}
